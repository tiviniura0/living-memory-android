import 'dart:async';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'security.dart';

enum MissionState {
  queued,
  running,
  awaitingPermission,
  succeeded,
  failed,
  cancelled,
  indeterminate,
}

final class Mission {
  Mission({required this.id, required this.state, required this.nextStep});
  final String id;
  final MissionState state;
  final int nextStep;
}

/// Foreground only. The host owns the supplied canonical (encrypted) database.
/// Construct once per host session; reconstruction recovers abandoned running rows.
final class MissionQueue {
  MissionQueue(
    this._db, {
    DateTime Function()? clock,
    this.stepTimeout = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now {
    if (stepTimeout <= Duration.zero ||
        stepTimeout > const Duration(minutes: 2))
      throw ArgumentError('Invalid step timeout');
    _db.execute(
      '''CREATE TABLE IF NOT EXISTS lm_v14_missions (
      id TEXT PRIMARY KEY, agent_id TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
      scope_json TEXT NOT NULL, due_at INTEGER NOT NULL,
      steps_json TEXT NOT NULL, state TEXT NOT NULL, next_step INTEGER NOT NULL DEFAULT 0)''',
    );
    _db.execute(
      "UPDATE lm_v14_missions SET state='indeterminate' WHERE state='running'",
    );
  }
  final Database _db;
  final DateTime Function() _clock;
  final Duration stepTimeout;
  bool _busy = false;
  bool _inFlight = false;
  void enqueue({
    required String id,
    required ExtensionScope scope,
    required DateTime dueAt,
    required List<Map<String, Object?>> steps,
  }) {
    if (id.isEmpty || id.length > 128 || steps.isEmpty || steps.length > 8)
      throw ArgumentError('Invalid mission');
    final frozenSteps = [for (final step in steps) frozenJson(step)];
    final encoded = jsonEncode(frozenSteps);
    if (utf8.encode(encoded).length > 65536)
      throw ArgumentError('Mission too large');
    _db.execute(
      'INSERT INTO lm_v14_missions(id,agent_id,scope_json,due_at,steps_json,state) VALUES(?,?,?,?,?,?)',
      [id, scope.agentId, scope.key, dueAt.millisecondsSinceEpoch, encoded, 'queued'],
    );
  }

  Mission? get(String id, {required ExtensionScope scope}) {
    final rows = _db.select(
      'SELECT id,state,next_step FROM lm_v14_missions WHERE id=? AND scope_json=?',
      [id, scope.key],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return Mission(
      id: row['id'] as String,
      state: MissionState.values.byName(row['state'] as String),
      nextStep: row['next_step'] as int,
    );
  }

  void cancel(String id, {required ExtensionScope scope}) {
    _db.execute(
      "UPDATE lm_v14_missions SET state='cancelled' WHERE id=? AND scope_json=? AND state IN ('queued','running','awaitingPermission')",
      [id, scope.key],
    );
  }

  Future<void> runDue({
    required ExtensionScope scope,
    required Future<void> Function(Mission mission, Map<String, Object?> step)
    execute,
  }) async {
    if (_busy || _inFlight) return;
    _busy = true;
    try {
      // At most eight effects across one activation, even across missions.
      var budget = 8;
      final rows = _db.select(
        "SELECT id,steps_json,next_step FROM lm_v14_missions WHERE scope_json=? AND state='queued' AND due_at<=? ORDER BY due_at,id LIMIT 8",
        [scope.key, _clock().millisecondsSinceEpoch],
      );
      for (final row in rows) {
        if (budget == 0) break;
        final id = row['id'] as String;
        _db.execute(
          "UPDATE lm_v14_missions SET state='running' WHERE id=? AND scope_json=? AND state='queued'",
          [id, scope.key],
        );
        if (_db.updatedRows != 1) continue;
        final steps = jsonDecode(row['steps_json'] as String) as List;
        var index = row['next_step'] as int;
        while (index < steps.length && budget > 0) {
          final mission = get(id, scope: scope)!;
          if (mission.state != MissionState.running) break;
          budget--;
          try {
            final step = frozenJson(Map<String, Object?>.from(steps[index] as Map));
            _inFlight = true;
            final effect = Future<void>.sync(() => execute(mission, step))
                .whenComplete(() { _inFlight = false; });
            await effect.timeout(stepTimeout);
          } on TimeoutException {
            _db.execute(
              "UPDATE lm_v14_missions SET state='indeterminate' WHERE id=? AND scope_json=? AND state='running'",
              [id, scope.key],
            );
            // The adapter is still running. No subsequent step or mission may
            // dispatch until it settles, even after this activation returns.
            return;
          } on ExtensionDenied {
            _db.execute(
              "UPDATE lm_v14_missions SET state='awaitingPermission' WHERE id=? AND scope_json=? AND state='running'",
              [id, scope.key],
            );
            break;
          } catch (_) {
            _db.execute(
              "UPDATE lm_v14_missions SET state='indeterminate' WHERE id=? AND scope_json=? AND state='running'",
              [id, scope.key],
            );
            break;
          }
          index++;
          _db.execute(
            "UPDATE lm_v14_missions SET next_step=?, state=? WHERE id=? AND scope_json=? AND state='running'",
            [
              index,
              index == steps.length ? 'succeeded' : 'running',
              id,
              scope.key,
            ],
          );
        }
        // Safe continuation is only for steps not yet dispatched; uncertain ones
        // remain indeterminate. A cancelled or recovered row is never revived.
        _db.execute(
          "UPDATE lm_v14_missions SET state='queued' WHERE id=? AND scope_json=? AND state='running'",
          [id, scope.key],
        );
      }
    } finally {
      _busy = false;
    }
  }
}
