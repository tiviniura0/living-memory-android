import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_memory_core/living_memory_core.dart' as core;
import 'package:living_memory_extensions/living_memory_extensions.dart' as ext;
import 'package:litert_edge_demos/living_memory/memory_store.dart' as old;

void main() {
  test('canonical core and historical import share type and persistent FTS', () {
    final dir = Directory.systemTemp.createTempSync('v14-core-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/memory.db';
    final store = core.MemoryStore.open(path, profile: 'test', dimension: 2);
    expect(store, isA<old.MemoryStore>());
    store.createAgent('a', 'A');
    store.addDocument(agentId: 'a', name: 'source', digest: 'digest',
      chunks: [const core.MemoryChunk(page: 1, ordinal: 1, text: 'Lagon vert')],
      vectors: [[1, 0]]);
    store.close();
    final reopened = old.MemoryStore.open(path, profile: 'test', dimension: 2);
    addTearDown(reopened.close);
    expect(reopened.searchText('a', 'lagon').single.text, 'Lagon vert');
    expect(reopened.search('a', [1, 0]), hasLength(1));
  });
  test('agent deletion removes persistent mission content without deleting another agent', () {
    final store = core.MemoryStore.open(':memory:', profile: 'test', dimension: 2);
    addTearDown(store.close);
    store.createAgent('a','A'); store.createAgent('b','B');
    final queue = ext.MissionQueue(store.extensionDatabase);
    final a = ext.ExtensionScope(agentId:'a', projectId:'p', worldId:'w');
    final b = ext.ExtensionScope(agentId:'b', projectId:'p', worldId:'w');
    queue.enqueue(id:'a-private',scope:a,dueAt:DateTime.now(),steps:[{'text':'SECRET_A'}]);
    queue.enqueue(id:'b-private',scope:b,dueAt:DateTime.now(),steps:[{'text':'SECRET_B'}]);
    store.deleteAgent('a');
    expect(queue.get('a-private',scope:a),isNull);
    expect(queue.get('b-private',scope:b),isNotNull);
  });

}
