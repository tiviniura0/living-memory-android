import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/auto_memory_candidate.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/reliability_engine.dart';

void main() {
  late Directory dir;
  late MemoryStore store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('reliability-');
    store = MemoryStore.open('${dir.path}/m.db', profile: 'test', dimension: 2);
    store.createAgent('aru', 'Aru'); store.createAgent('bea', 'Bea');
  });
  tearDown(() { store.close(); dir.deleteSync(recursive: true); });
  test('FTS rescues exact terminology missed by cosine and isolates agents', () {
    for (final agent in ['aru', 'bea']) {
      store.addDocument(agentId: agent, name: 'source', digest: 'a',
        chunks: [const MemoryChunk(page: 1, ordinal: 1, text: 'Le code zirconium est ZR42.')], vectors: [[0, 1]]);
    }
    final hits = ReliabilityEngine(store).retrieve('aru', 'zirconium', [1, 0]);
    expect(hits, hasLength(1)); expect(hits.single.agentId, 'aru');
    expect(hits.single.text, contains('ZR42'));
    expect(ReliabilityEngine(store).retrieve('aru', '" OR *', [1, 0]), isEmpty);
    store.deleteDocument('aru', hits.single.documentId);
    expect(ReliabilityEngine(store).retrieve('aru', 'zirconium', [1, 0]), isEmpty);
  });
  test('project retrieval cannot use a document from another project', () {
    store.addDocument(agentId: 'aru', name: 'private', digest: 'p', projectId: 'p',
      chunks: [const MemoryChunk(page: 1, ordinal: 1, text: 'zirconium privé')], vectors: [[1, 0]]);
    final engine = ReliabilityEngine(store);
    expect(engine.retrieve('aru', 'zirconium', [1, 0]), isEmpty);
    expect(engine.retrieve('aru', 'zirconium', [1, 0], projectId: 'p'), hasLength(1));
  });
  test('empty evidence, uncited output and out-of-range citations abstain', () {
    final engine = ReliabilityEngine(store);
    final hit = MemoryHit(agentId: 'aru', documentId: 'd', name: 's', page: 1,
      ordinal: 1, text: 'Une déclaration.', similarity: 1);
    expect(engine.validateAnswer('Une réponse [1]', []).accepted, isFalse);
    expect(engine.validateAnswer('Invention sans citation', [hit]).accepted, isFalse);
    expect(engine.validateAnswer('Fait [2]', [hit]).accepted, isFalse);
    expect(engine.validateAnswer('Déclaration selon la source [1]', [hit]).accepted, isTrue);
  });
  test('archiving is versioned and excludes confirmed memory from retrieval', () {
    final doc = store.addDocument(agentId: 'aru', name: 'note', digest: 'a',
      chunks: [const MemoryChunk(page: 1, ordinal: 1, text: 'Aru est ici.')], vectors: [[1, 0]]);
    final id = store.addMemory(agentId: 'aru', documentId: doc, ordinal: 1,
      candidate: const AutoMemoryCandidate(quote: 'Aru est ici.', kind: 'observation',
        subject: '', relation: '', value: '', uncertain: true), vector: [1, 0], extractor: 'test');
    store.confirmMemory('aru', id);
    expect(() => store.archiveMemory('bea', id), throwsStateError);
    store.archiveMemory('aru', id);
    expect(store.memoryRecord('aru', id)!.status, 'archived');
    expect(store.memoryHistory('aru', id), hasLength(3));
    expect(store.searchMemories('aru', [1, 0]), isEmpty);
    expect(store.documents('aru'), hasLength(1));
  });
}
