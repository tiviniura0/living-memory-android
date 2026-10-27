import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/context_lifecycle_manager.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'schema 3 checkpoints are copied once and original messages survive',
    () {
      final dir = Directory.systemTemp.createTempSync('schema3-');
      final path = '${dir.path}/m.db';
      var store = MemoryStore.open(path, profile: 'test', dimension: 2);
      store.createAgent('aru', 'Aru');
      final manager = ContextLifecycleManager(
        store,
        const MemoryScope(agentId: 'aru'),
      );
      final id = manager.startSession();
      manager.append(id, 'user', 'Décision conservée', decision: true);
      store.close();
      final db = sqlite3.open(path);
      db.execute('DROP TABLE context_checkpoint_events');
      for (final trigger in [
        'session_fts_insert',
        'session_fts_delete',
        'session_fts_update',
      ]) {
        db.execute('DROP TRIGGER $trigger');
      }
      db.execute('DROP TABLE session_fts');
      db.execute('INSERT INTO context_checkpoints VALUES(?,?,?,?,?,?)', [
        'legacy',
        id,
        1,
        'Résumé ancien',
        'compact',
        '2026-10-26',
      ]);
      db.execute('PRAGMA user_version=3');
      db.close();
      for (var i = 0; i < 2; i++) {
        store = MemoryStore.open(path, profile: 'test', dimension: 2);
        final restored = ContextLifecycleManager(
          store,
          const MemoryScope(agentId: 'aru'),
        );
        expect(restored.checkpoints(id).single.id, 'legacy');
        expect(restored.messages(id).single.text, 'Décision conservée');
        expect(
          store.searchDecisions(
            const MemoryScope(agentId: 'aru').key,
            'aru',
            'conservée',
          ),
          hasLength(1),
        );
        store.close();
      }
      dir.deleteSync(recursive: true);
    },
  );
}
