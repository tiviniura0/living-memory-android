import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:world_contracts/world_contracts.dart';

import 'grid_pathfinder.dart';

class WorldCore {
  late Map<String, dynamic> _s;
  bool paused = false;
  WorldCore(WorldState initial) {
    WorldCodec.validate(initial.toJson());
    _s = initial.toJson();
  }
  WorldSnapshot snapshot() => WorldSnapshot(WorldState(_s));
  void setPaused(bool value) {
    if (paused != value) {
      paused = value;
      _s['revision']++;
    }
  }

  ActionResult setPopulationMax(int v) {
    if (v < 1 || v > 1000)
      return const ActionResult(
        'admin',
        ActionStatus.rejected,
        'invalid_arguments',
      );
    _s['config']['populationMax'] = v;
    _s['revision']++;
    return const ActionResult('admin', ActionStatus.applied, 'ok');
  }

  ActionResult addAgent(AgentState a) {
    if ((_s['agents'] as List).length >= _s['config']['populationMax'])
      return const ActionResult(
        'admin',
        ActionStatus.rejected,
        'population_cap',
      );
    final copy = snapshot().state.toJson();
    (copy['agents'] as List).add(a.toJson());
    try {
      WorldCodec.validate(copy);
    } catch (_) {
      return const ActionResult(
        'admin',
        ActionStatus.rejected,
        'invalid_actor',
      );
    }
    _s = copy;
    _s['revision']++;
    return const ActionResult('admin', ActionStatus.applied, 'ok');
  }

  void finishDecisionRound() {
    if (paused) return;
    final n = (_s['agents'] as List).length;
    _s['schedulerCursor'] = n == 0 ? 0 : (_s['schedulerCursor'] + 1) % n;
    _s['revision']++;
  }

  String issueCommandId(String actor) {
    if (paused) throw StateError('paused');
    if (!(_s['agents'] as List).any((a) => a['id'] == actor))
      throw ArgumentError('actor');
    _s['decisionSequence']++;
    _s['revision']++;
    return sha256
        .convert(
          utf8.encode(
            canonicalJson([
              _s['worldId'],
              actor,
              _s['tick'],
              _s['decisionSequence'],
            ]),
          ),
        )
        .toString();
  }

  // Explicit scheduler feedback is a core mutation, never a mutable snapshot edit.
  void recordFailure(String actor, String code) {
    if (paused) return;
    final a = (_s['agents'] as List).firstWhere((a) => a['id'] == actor);
    a['failureCount']++;
    a['nextDecisionTick'] = _s['tick'] + 40;
    a['goal'] = 'attendre';
    _s['revision']++;
    _event('action_failed', actor, {
      'code': code,
      'retryTick': a['nextDecisionTick'],
    });
  }

  void abandonAction(String actor) {
    if (paused) return;
    final ps = List.from(_s['pendingActions'])
        .where((p) => p['actorId'] == actor);
    for (final p in ps) {
      _finish(p);
    }
    _s['revision']++;
  }

  ActionResult submit(ActionProposal c) {
    ActionResult reject(String code) =>
        ActionResult(c.commandId, ActionStatus.rejected, code);
    try {
      ActionProposal.fromJson(c.toJson());
    } catch (_) {
      return reject('invalid_arguments');
    }
    if ((_s['appliedCommandIds'] as List).contains(c.commandId))
      return reject('duplicate');
    if (paused) return reject('paused');
    if (c.data['worldId'] != _s['worldId']) return reject('wrong_world');
    if (c.data['expiresTick'] < _s['tick'] || c.data['issuedTick'] > _s['tick'])
      return reject('expired');
    if (c.data['expectedRevision'] != _s['revision'])
      return reject('stale_revision');
    final list = (_s['agents'] as List).where((a) => a['id'] == c.actorId);
    if (list.isEmpty) return reject('invalid_actor');
    final a = list.first;
    if (a['currentAction'] != null) return reject('actor_busy');
    int duration = 0;
    Map? resource;
    final events = <WorldEvent>[];
    switch (c.kind) {
      case ActionKind.move:
        final path = GridPathfinder().findPath(
          snapshot().state,
          GridPos.fromJson(a['position']),
          GridPos(c.arguments['x'], c.arguments['y']),
        );
        if (path == null) return reject('unreachable');
        duration = path.length;
        a['goal'] = 'explorer';
      case ActionKind.gather:
        final rs = (_s['resources'] as List).where(
          (r) => r['id'] == c.arguments['resourceId'],
        );
        if (rs.isEmpty) return reject('unavailable_resource');
        resource = rs.first as Map;
        if (resource['food'] <= 0 || resource['reservationAgentId'] != null)
          return reject('unavailable_resource');
        if (GridPos.fromJson(a['position'])
                .distance(GridPos.fromJson(resource['position'])) >
            1)
          return reject('invalid_arguments');
        duration = 4;
        a['goal'] = 'se nourrir';
      case ActionKind.consume:
        if (a['inventoryFood'] <= 0) return reject('insufficient_inventory');
        a['goal'] = 'se nourrir';
      case ActionKind.rest:
        duration = 40;
        a['goal'] = 'se reposer';
    }
    _s['revision']++;
    final ids = _s['appliedCommandIds'] as List;
    ids.add(c.commandId);
    if (ids.length > 1024) ids.removeAt(0);
    if (c.kind == ActionKind.consume) {
      final before = a['hunger'];
      a['inventoryFood']--;
      a['hunger'] = (a['hunger'] - 40).clamp(0, 100);
      events.add(
        _event('consumed', a['id'], {
          'hungerBefore': before,
          'hungerAfter': a['hunger'],
          'inventoryAfter': a['inventoryFood'],
        }, c.commandId),
      );
    }
    if (duration > 0) {
      a['currentAction'] = c.commandId;
      (_s['pendingActions'] as List).add({
        'commandId': c.commandId,
        'actorId': c.actorId,
        'kind': c.kind.name,
        'arguments': c.arguments,
        'startedTick': _s['tick'],
        'dueTick': _s['tick'] + duration,
        'reservedResourceId': resource?['id'],
        'status': 'pending',
      });
    }
    if (resource != null) {
      resource['reservationAgentId'] = a['id'];
      resource['reservationUntilTick'] = _s['tick'] + duration;
      events.add(
        _event('resource_reserved', a['id'], {
          'resourceId': resource['id'],
          'food': resource['food'],
        }, c.commandId),
      );
    }
    events.add(
      _event('action_started', a['id'], {
        'kind': c.kind.name,
        'mode': 'rules',
      }, c.commandId),
    );
    return ActionResult(
      c.commandId,
      duration > 0 ? ActionStatus.pending : ActionStatus.applied,
      'ok',
      List.unmodifiable(events),
    );
  }

  void _finish(Map p) {
    final a = (_s['agents'] as List).firstWhere((a) => a['id'] == p['actorId']);
    a['currentAction'] = null;
    for (final r in _s['resources']) {
      if (r['id'] == p['reservedResourceId'] &&
          r['reservationAgentId'] == p['actorId']) {
        r['reservationAgentId'] = null;
        r['reservationUntilTick'] = null;
      }
    }
    (_s['pendingActions'] as List).remove(p);
  }

  List<WorldEvent> step(int ticks) {
    RangeError.checkValueInInterval(ticks, 0, 1000);
    if (paused) return [];
    final events = <WorldEvent>[];
    for (var i = 0; i < ticks; i++) {
      _s['tick']++;
      _s['revision']++;
      if (_s['tick'] % 40 == 0) {
        for (final a in _s['agents']) {
          final resting = (_s['pendingActions'] as List).any(
            (p) => p['actorId'] == a['id'] && p['kind'] == 'rest',
          );
          a['hunger'] = (a['hunger'] + 1).clamp(0, 100);
          a['energy'] = (a['energy'] + (resting ? 4 : -1)).clamp(0, 100);
        }
      }
      for (final p in List.from(_s['pendingActions'])) {
        final a = (_s['agents'] as List).firstWhere(
          (a) => a['id'] == p['actorId'],
        );
        if (p['kind'] == 'move') {
          final path = GridPathfinder().findPath(
            snapshot().state,
            GridPos.fromJson(a['position']),
            GridPos.fromJson(p['arguments']),
          );
          if (path == null) {
            _finish(p);
            events.add(
              _event('action_failed', a['id'], {
                'code': 'unreachable',
              }, p['commandId']),
            );
            continue;
          }
          if (path.isNotEmpty) a['position'] = path.first.toJson();
          if (path.length <= 1) _finish(p);
          events.add(
            _event('moved', a['id'], {
              'position': a['position'],
            }, p['commandId']),
          );
        } else if (p['dueTick'] <= _s['tick']) {
          if (p['kind'] == 'gather') {
            final rs = (_s['resources'] as List).where(
              (r) => r['id'] == p['reservedResourceId'],
            );
            if (rs.isEmpty ||
                rs.first['reservationAgentId'] != a['id'] ||
                rs.first['food'] <= 0 ||
                GridPos.fromJson(a['position'])
                        .distance(GridPos.fromJson(rs.first['position'])) >
                    1) {
              events.add(
                _event('action_failed', a['id'], {
                  'code': 'unavailable_resource',
                }, p['commandId']),
              );
            } else {
              final r = rs.first;
              final before = r['food'];
              r['food']--;
              a['inventoryFood']++;
              events.add(
                _event('collected', a['id'], {
                  'resourceId': r['id'],
                  'foodBefore': before,
                  'foodAfter': r['food'],
                  'inventoryAfter': a['inventoryFood'],
                }, p['commandId']),
              );
            }
          } else if (p['kind'] == 'rest') {
            events.add(
              _event('rested', a['id'], {
                'energy': a['energy'],
              }, p['commandId']),
            );
          }
          _finish(p);
        }
      }
      for (final r in _s['resources']) {
        if (r['reservationAgentId'] != null &&
            r['reservationUntilTick'] <= _s['tick']) {
          r['reservationAgentId'] = null;
          r['reservationUntilTick'] = null;
        }
      }
    }
    return events;
  }

  WorldEvent _event(
    String kind,
    String? actor,
    Map<String, dynamic> payload, [
    String? command,
  ]) {
    final logEntries = _s['eventLog'] as List;
    var index = 0;
    for (
      var i = logEntries.length - 1;
      i >= 0 && logEntries[i]['revision'] == _s['revision'];
      i--
    ) {
      index++;
    }
    final event = {
      'schemaVersion': 1,
      'eventId': sha256
          .convert(
            utf8.encode(canonicalJson([_s['worldId'], _s['revision'], index])),
          )
          .toString(),
      'worldId': _s['worldId'],
      'tick': _s['tick'],
      'revision': _s['revision'],
      'actorId': actor,
      'kind': kind,
      'payload': payload,
      'commandId': command,
      'observedBy': <String>[],
    };
    final actors = (_s['agents'] as List).where((a) => a['id'] == actor);
    if (actors.isNotEmpty) {
      final pos = GridPos.fromJson(actors.first['position']);
      event['observedBy'] = [
        for (final a in _s['agents'])
          if (GridPos.fromJson(a['position']).distance(pos) <= 6) a['id'],
      ];
    }
    final log = _s['eventLog'] as List;
    log.add(freeze(event));
    if (log.length > 10000) log.removeAt(0);
    return WorldEvent.fromJson(event);
  }
}
