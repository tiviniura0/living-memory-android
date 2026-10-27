import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';

void main() {
  late Directory dir;
  late MemoryStore store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('living-memory-test-');
    store = MemoryStore.open(
      '${dir.path}/memory.db',
      profile: 'test',
      dimension: 2,
    );
    store.createAgent('aru', 'Aru');
    store.createAgent('bea', 'Bea');
  });
  tearDown(() {
    store.close();
    dir.deleteSync(recursive: true);
  });

  String add(String agent, String hash, List<double> vector) =>
      store.addDocument(
        agentId: agent,
        name: 'source.txt',
        digest: hash,
        chunks: [
          const MemoryChunk(page: 1, ordinal: 1, text: 'La clé est verte.'),
        ],
        vectors: [vector],
      );

  test('search filters agent before ranking, including identical vectors', () {
    add('aru', 'a', [1, 0]);
    add('bea', 'b', [1, 0]);
    expect(store.search('aru', [1, 0]).map((h) => h.agentId), ['aru']);
    expect(store.search('bea', [0, 1], minSimilarity: 0.5), isEmpty);
  });
  test('cosine ranking and zero-vector rejection', () {
    add('aru', 'a', [1, 0]);
    add('aru', 'b', [0.5, 0.5]);
    final hits = store.search('aru', [1, 0], minSimilarity: 0);
    expect(hits.first.similarity, closeTo(1, 1e-8));
    expect(hits.last.similarity, closeTo(0.70710678, 1e-7));
    expect(() => store.search('aru', [0, 0]), throwsArgumentError);
  });
  test(
    'duplicate import per agent is idempotent; another agent is independent',
    () {
      expect(add('aru', 'a', [1, 0]), add('aru', 'a', [1, 0]));
      add('bea', 'a', [1, 0]);
      expect(store.documents('aru'), hasLength(1));
      expect(store.documents('bea'), hasLength(1));
    },
  );
  test('invalid vectors never commit partial documents', () {
    for (final vector in [
      [double.nan, 0.0],
      [double.infinity, 1.0],
      [1e-300, 0.0],
      [0.0, 0.0],
      [1.0],
    ]) {
      expect(() => add('aru', 'bad', vector), throwsArgumentError);
      expect(store.documents('aru'), isEmpty);
    }
  });
  test('a constraint failure rolls back every passage and the document', () {
    expect(
      () => store.addDocument(
        agentId: 'aru',
        name: 'broken.txt',
        digest: 'broken',
        chunks: [
          const MemoryChunk(page: 1, ordinal: 1, text: 'first'),
          const MemoryChunk(page: 2, ordinal: 1, text: 'duplicate ordinal'),
        ],
        vectors: [
          [1, 0],
          [1, 0],
        ],
      ),
      throwsException,
    );
    expect(store.documents('aru'), isEmpty);
    expect(store.search('aru', [1, 0]), isEmpty);
    add('aru', 'valid-after-rollback', [1, 0]);
    expect(store.documents('aru'), hasLength(1));
  });

  test('document deletion cannot cross agent boundary', () {
    final id = add('aru', 'a', [1, 0]);
    store.deleteDocument('bea', id);
    expect(store.search('aru', [1, 0]), hasLength(1));
    store.deleteDocument('aru', id);
    expect(store.search('aru', [1, 0]), isEmpty);
  });
  test(
    'data persists and another embedding profile is refused without erasure',
    () {
      add('aru', 'a', [1, 0]);
      store.close();
      expect(
        () => MemoryStore.open(
          '${dir.path}/memory.db',
          profile: 'other',
          dimension: 2,
        ),
        throwsStateError,
      );
      store = MemoryStore.open(
        '${dir.path}/memory.db',
        profile: 'test',
        dimension: 2,
      );
      expect(store.search('aru', [1, 0]), hasLength(1));
    },
  );
  test('agent identifiers reject traversal and SQL text', () {
    expect(() => store.createAgent('../aru', 'bad'), throwsArgumentError);
    expect(
      () => store.createAgent("'; DROP TABLE agents; --", 'bad'),
      throwsArgumentError,
    );
    expect(store.agents(), hasLength(2));
  });
}
