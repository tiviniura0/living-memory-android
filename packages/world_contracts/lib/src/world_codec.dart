import 'dart:convert';

import 'world_types.dart';

class WorldCodec {
  static String encode(WorldState state) => canonicalJson(state.data);
  static WorldState decode(String value) {
    if (utf8.encode(value).length > 16 * 1024 * 1024)
      throw const FormatException('Snapshot too large');
    try {
      final s = jsonDecode(value) as Map<String, dynamic>;
      validate(s);
      return WorldState(s);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed snapshot');
    }
  }

  static void validate(Map<String, dynamic> s) {
    void check(bool b) {
      if (!b) throw const FormatException('Invalid snapshot');
    }

    bool id(dynamic v) =>
        v is String && RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(v);
    bool num(dynamic v, int min, int max) => v is int && v >= min && v <= max;
    final c = s['config'] as Map;
    check(
      c['schemaVersion'] == 1 && c['rulesVersion'] == 1 && id(s['worldId']),
    );
    check(
      num(c['seed'], 1, 0xffffffff) &&
          num(c['width'], 1, 256) &&
          num(c['height'], 1, 256) &&
          num(c['populationMax'], 1, 1000),
    );
    for (final k in [
      'tick',
      'revision',
      'schedulerCursor',
      'decisionSequence',
    ]) {
      check(num(s[k], 0, 9007199254740991));
    }
    check(num(s['rngState'], 1, 0xffffffff));
    bool pos(dynamic p) =>
        p is Map &&
        p.length == 2 &&
        num(p['x'], 0, c['width'] - 1) &&
        num(p['y'], 0, c['height'] - 1);
    final agents = s['agents'] as List,
        resources = s['resources'] as List,
        pending = s['pendingActions'] as List,
        events = s['eventLog'] as List,
        blocked = s['blockedCells'] as List;
    check(
      agents.length <= 1000 &&
          resources.length <= 65536 &&
          events.length <= 10000 &&
          blocked.length <= 65536 &&
          pending.length <= agents.length,
    );
    final ids = <String>{}, rids = <String>{}, bpos = <String>{};
    for (final p in blocked) {
      check(pos(p) && bpos.add(canonicalJson(p)));
    }
    for (final a in agents) {
      check(
        id(a['id']) &&
            ids.add(a['id']) &&
            pos(a['position']) &&
            !bpos.contains(canonicalJson(a['position'])),
      );
      check(
        a['name'] is String &&
            a['name'].length <= 128 &&
            a['goal'] is String &&
            a['goal'].length <= 128 &&
            a['behaviorProfile'] == 'local_v1',
      );
      for (final k in ['hunger', 'energy']) {
        check(num(a[k], 0, 100));
      }
      for (final k in ['inventoryFood', 'failureCount', 'nextDecisionTick']) {
        check(num(a[k], 0, 9007199254740991));
      }
      check(a['currentAction'] == null || id(a['currentAction']));
    }
    for (final r in resources) {
      check(
        id(r['id']) &&
            rids.add(r['id']) &&
            pos(r['position']) &&
            !bpos.contains(canonicalJson(r['position'])) &&
            num(r['food'], 0, 9007199254740991),
      );
      check(
        r['reservationAgentId'] == null && r['reservationUntilTick'] == null ||
            ids.contains(r['reservationAgentId']) &&
                num(r['reservationUntilTick'], s['tick'], 9007199254740991),
      );
    }
    final busy = <String>{}, commands = <String>{};
    for (final p in pending) {
      check(
        id(p['commandId']) &&
            commands.add(p['commandId']) &&
            ids.contains(p['actorId']) &&
            busy.add(p['actorId']) &&
            ActionKind.values.any((k) => k.name == p['kind']) &&
            p['arguments'] is Map &&
            p['status'] == 'pending' &&
            num(p['startedTick'], 0, s['tick']) &&
            num(p['dueTick'], s['tick'] + 1, 9007199254740991),
      );
      check(
        p['reservedResourceId'] == null ||
            rids.contains(p['reservedResourceId']),
      );
      final a = agents.firstWhere((a) => a['id'] == p['actorId']);
      check(a['currentAction'] == p['commandId']);
      if (p['kind'] == 'move') {
        check(pos(p['arguments']));
      }
      if (p['kind'] == 'gather') {
        check(
          rids.contains(p['arguments']['resourceId']) &&
              p['reservedResourceId'] == p['arguments']['resourceId'],
        );
      }
    }
    for (final a in agents) {
      check(
        a['currentAction'] == null || commands.contains(a['currentAction']),
      );
    }
    for(final r in resources){
      if(r['reservationAgentId']!=null){
        check(pending.any((p)=>p['kind']=='gather'&&p['actorId']==r['reservationAgentId']&&p['reservedResourceId']==r['id']&&p['dueTick']==r['reservationUntilTick']));
      }
    }
    for(final p in pending){
      if(p['kind']=='gather'){
        final r=resources.firstWhere((r)=>r['id']==p['reservedResourceId']);
        check(r['reservationAgentId']==p['actorId']&&r['food']>0);
      }
    }
    final applied = s['appliedCommandIds'] as List;
    check(
      applied.length <= 1024 &&
          applied.toSet().length == applied.length &&
          applied.every(id),
    );
    final eids = <String>{};
    for (final e in events) {
      check(
        e['schemaVersion'] == 1 &&
            id(e['eventId']) &&
            eids.add(e['eventId']) &&
            e['worldId'] == s['worldId'] &&
            num(e['tick'], 0, s['tick']) &&
            num(e['revision'], 0, s['revision']) &&
            (e['actorId'] == null || ids.contains(e['actorId'])) &&
            e['kind'] is String &&
            e['payload'] is Map &&
            (e['observedBy'] as List).every(ids.contains),
      );
    }
  }
}
