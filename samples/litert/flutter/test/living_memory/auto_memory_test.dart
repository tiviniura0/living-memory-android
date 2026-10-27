import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/auto_memory_candidate.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late MemoryStore store;
  late String source;
  const quote = 'Aru habite à Mahina.';
  const other = 'Aru habite à Taravao.';
  const candidate = AutoMemoryCandidate(
    quote: quote,
    kind: 'observation',
    subject: 'Aru',
    relation: 'habite',
    value: 'Mahina',
    uncertain: false,
  );
  setUp(() {
    dir = Directory.systemTemp.createTempSync('auto-memory-');
    store = MemoryStore.open(
      '${dir.path}/v1.db',
      profile: 'test',
      dimension: 2,
    );
    store.createAgent('aru', 'Aru');
    store.createAgent('bea', 'Bea');
    source = store.addDocument(
      agentId: 'aru',
      name: 'Note',
      digest: 'a',
      chunks: [const MemoryChunk(page: 1, ordinal: 1, text: '$quote $other')],
      vectors: [
        [1, 0],
      ],
      kind: 'note',
    );
  });
  tearDown(() {
    store.close();
    dir.deleteSync(recursive: true);
  });
  String add([AutoMemoryCandidate c = candidate]) => store.addMemory(
    agentId: 'aru',
    documentId: source,
    ordinal: 1,
    candidate: c,
    vector: [1, 0],
    extractor: 'Gemma 4 E2B/extractive-v1',
  );

  test('migration preserves true V1 schema and data and refuses future schema', () {
    store.close();
    final db = sqlite3.open('${dir.path}/legacy.db');
    db.execute(
      'CREATE TABLE profile(id INTEGER PRIMARY KEY, name TEXT, dimension INTEGER)',
    );
    db.execute("INSERT INTO profile VALUES(1,'test',2)");
    db.execute('CREATE TABLE agents(id TEXT PRIMARY KEY,name TEXT NOT NULL)');
    db.execute("INSERT INTO agents VALUES('old','Old')");
    db.execute(
      'CREATE TABLE documents(id TEXT PRIMARY KEY,agent_id TEXT REFERENCES agents(id),name TEXT,digest TEXT,kind TEXT,created_at TEXT,UNIQUE(agent_id,digest))',
    );
    db.execute(
      "INSERT INTO documents VALUES('doc','old','source','hash','note','date')",
    );
    db.execute(
      'CREATE TABLE chunks(document_id TEXT REFERENCES documents(id) ON DELETE CASCADE,page INTEGER,ordinal INTEGER,content TEXT,vector TEXT,PRIMARY KEY(document_id,ordinal))',
    );
    db.execute("INSERT INTO chunks VALUES('doc',1,1,'ancien','[1,0]')");
    db.close();
    store = MemoryStore.open(
      '${dir.path}/legacy.db',
      profile: 'test',
      dimension: 2,
    );
    expect(store.search('old', [1, 0]).single.text, 'ancien');
    expect(store.autoMemoryEnabled('old'), isFalse);
    store.close();
    final future = sqlite3.open('${dir.path}/legacy.db');
    future.execute('PRAGMA user_version=99');
    future.close();
    expect(
      () => MemoryStore.open(
        '${dir.path}/legacy.db',
        profile: 'test',
        dimension: 2,
      ),
      throwsStateError,
    );
    store = MemoryStore.open(
      '${dir.path}/v1.db',
      profile: 'test',
      dimension: 2,
    );
  });
  test('opt-in persists per agent and sources are bounded', () {
    expect(store.autoMemoryEnabled('aru'), isFalse);
    store.setAutoMemoryEnabled('aru', enabled: true);
    expect(store.autoMemoryEnabled('bea'), isFalse);
    store.close();
    store = MemoryStore.open(
      '${dir.path}/v1.db',
      profile: 'test',
      dimension: 2,
    );
    expect(store.autoMemoryEnabled('aru'), isTrue);
    expect(store.memoryPassages('aru', source).single.text, '$quote $other');
    expect(store.memoryPassages('bea', source), isEmpty);
  });
  test(
    'grounded candidates remain unverified and exact duplicates are idempotent',
    () {
      final id = add();
      expect(add(), id);
      final m = store.memories('aru').single;
      expect(m.status, 'pending');
      expect(m.text, quote);
      expect(m.quote, quote);
      expect(m.extractor, contains('Gemma'));
      expect(m.page, 1);
      expect(m.agentId, 'aru');
      expect(m.version, 1);
      expect(m.createdAt, isNotEmpty);
      expect(m.sourceName, 'Note');
      expect(store.memories('bea'), isEmpty);
      expect(store.memoryHistory('aru', id), hasLength(1));
    },
  );
  test(
    'fabricated quote, wrong owner, invalid vector are rejected atomically',
    () {
      expect(
        () => add(
          const AutoMemoryCandidate(
            quote: 'inventé',
            kind: 'observation',
            subject: 'A',
            relation: 'r',
            value: 'v',
            uncertain: false,
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => store.addMemory(
          agentId: 'bea',
          documentId: source,
          ordinal: 1,
          candidate: candidate,
          vector: [1, 0],
          extractor: 'test',
        ),
        throwsStateError,
      );
      expect(
        () => store.addMemory(
          agentId: 'aru',
          documentId: source,
          ordinal: 1,
          candidate: candidate,
          vector: [double.nan, 0],
          extractor: 'test',
        ),
        throwsArgumentError,
      );
      expect(store.memories('aru'), isEmpty);
    },
  );
  test(
    'similarity flags potential duplicate and conflicting slot without merging',
    () {
      final a = add();
      final b = add(
        const AutoMemoryCandidate(
          quote: other,
          kind: 'observation',
          subject: 'Aru',
          relation: 'habite',
          value: 'Taravao',
          uncertain: true,
        ),
      );
      expect(store.memories('aru'), hasLength(2));
      expect(
        store.memoryLinks('aru', a).map((l) => l.kind),
        contains('possible_contradiction'),
      );
      expect(store.memoryLinks('aru', a).map((l) => l.otherId), contains(b));
      expect(store.memoryLinks('bea', a), isEmpty);
      expect(store.memories('aru').every((m) => m.status == 'review'), isTrue);
    },
  );
  test(
    'correction is versioned, scoped, re-embedded and never silently verified',
    () {
      final id = add();
      expect(
        () => store.correctMemory('bea', id, 'Correction', [0, 1]),
        throwsStateError,
      );
      store.correctMemory('aru', id, 'Correction manuelle', [0, 1]);
      final m = store.memories('aru').single;
      expect(m.text, 'Correction manuelle');
      expect(m.quote, quote);
      expect(m.version, 2);
      expect(m.status, 'pending');
      expect(store.memoryHistory('aru', id).first, contains(quote));
      store.confirmMemory('aru', id);
      expect(store.memories('aru').single.status, 'user_confirmed');
      expect(store.memoryHistory('aru', id), hasLength(3));
    },
  );
  test('deletion purges revisions and links; document removal cascades', () {
    final id = add();
    store.deleteMemory('bea', id);
    expect(store.memories('aru'), hasLength(1));
    store.deleteMemory('aru', id);
    expect(store.memoryHistory('aru', id), isEmpty);
    add();
    store.deleteDocument('aru', source);
    expect(store.memories('aru'), isEmpty);
    expect(store.memoryHistory('aru', id), isEmpty);
  });
  test('explicit grouping preserves both sources and never confirms facts', () {
    final a = add();
    final b = add(
      const AutoMemoryCandidate(
        quote: other,
        kind: 'inference',
        subject: '',
        relation: '',
        value: '',
        uncertain: true,
      ),
    );
    store.groupMemories('aru', a, b);
    expect(store.memories('aru'), hasLength(2));
    expect(
      store.memoryLinks('aru', a).map((l) => l.kind),
      contains('user_grouped'),
    );
    expect(() => store.groupMemories('bea', a, b), throwsStateError);
    expect(
      store.memories('aru').any((m) => m.status == 'user_confirmed'),
      isFalse,
    );
  });
  test(
    'only explicitly confirmed memories enter retrieval with corrected text',
    () {
      final id = add();
      expect(store.searchMemories('aru', [1, 0]), isEmpty);
      store.confirmMemory('aru', id);
      expect(store.searchMemories('bea', [1, 0]), isEmpty);
      expect(store.searchMemories('aru', [1, 0]).single.text, contains(quote));
      store.correctMemory('aru', id, 'Correction', [0, 1]);
      expect(store.searchMemories('aru', [0, 1]), isEmpty);
      store.confirmMemory('aru', id);
      expect(
        store.searchMemories('aru', [0, 1]).single.text,
        contains('Correction'),
      );
      expect(store.searchMemories('aru', [1, 0], minSimilarity: 0.8), isEmpty);
      expect(() => store.searchMemories('aru', [0, 0]), throwsArgumentError);
    },
  );
  test('strict parser rejects unsupported, malformed, oversized and ungrounded output', () {
    expect(AutoMemoryCandidate.parse('[]', quote), isEmpty);
    final valid =
        '[{"quote":"$quote","kind":"observation","subject":"Aru","relation":"habite","value":"Mahina","uncertain":false}]';
    expect(AutoMemoryCandidate.parse(valid, quote).single.quote, quote);
    for (final bad in [
      '```json\n$valid\n```',
      '{}',
      'x' * 6001,
      '[{"quote":"inventé"}]',
      valid.replaceAll('observation', 'verified'),
      valid.replaceAll('false', '0'),
      valid.replaceAll(
        '"uncertain":false',
        '"uncertain":false,"verified":true',
      ),
      '[${List.filled(4, valid.substring(1, valid.length - 1)).join(',')}]',
    ]) {
      expect(
        () => AutoMemoryCandidate.parse(bad, quote),
        throwsFormatException,
        reason: bad,
      );
    }
  });
}
