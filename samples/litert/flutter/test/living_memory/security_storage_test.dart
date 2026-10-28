import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';

void main() {
  const key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('memory-security-');
    path = '${dir.path}/memory.db';
  });
  tearDown(() => dir.deleteSync(recursive: true));
  MemoryStore open({String? encryptionKey}) => MemoryStore.open(
    path, profile: 'test', dimension: 2, encryptionKey: encryptionKey,
  );
  void seed(MemoryStore store, String agent) {
    store.createAgent(agent, agent);
    store.addDocument(agentId: agent, name: 'private-name', digest: agent,
      chunks: [const MemoryChunk(page: 1, ordinal: 1, text: 'SECRET_LAGON42')],
      vectors: [[1, 0]]);
  }
  test('plaintext migration preserves schema, FTS, sessions and encrypted reopen', () {
    final plain = open();
    seed(plain, 'a');
    final scope = const MemoryScope(agentId: 'a').key;
    final session = plain.createSession(scope, 'a');
    plain.appendSessionMessage(scope, session, 'user', 'SECRET_LAGON42', decision: true);
    plain.writeCheckpoint(scope, session, 1, 'SECRET_LAGON42', 'compact');
    plain.close();
    final encrypted = open(encryptionKey: key);
    expect(encrypted.documents('a'), hasLength(1));
    expect(encrypted.searchText('a', 'SECRET_LAGON42'), hasLength(1));
    expect(encrypted.searchDecisions(scope, 'a', 'SECRET_LAGON42'), hasLength(1));
    expect(encrypted.sessionCheckpoints(scope, session).single.summary, 'SECRET_LAGON42');
    encrypted.close();
    expect(String.fromCharCodes(File(path).readAsBytesSync()), isNot(contains('SECRET_LAGON42')));
    expect(() { final db = sqlite3.open(path); try { db.select('SELECT * FROM agents'); } finally { db.close(); } }, throwsA(anything));
    final reopened = open(encryptionKey: key);
    expect(reopened.agents().single.id, 'a');
    reopened.close();
  });
  test('wrong key never destroys existing encrypted database', () {
    final db = open(encryptionKey: key);
    seed(db, 'a'); db.close();
    final before = File(path).readAsBytesSync();
    expect(() => open(encryptionKey: List.filled(64, 'a').join()), throwsA(anything));
    expect(File(path).readAsBytesSync(), before);
    final good = open(encryptionKey: key); expect(good.agents(), hasLength(1)); good.close();
  });
  test('future plaintext schema is not replaced during encryption', () {
    final db = sqlite3.open(path); db.execute('PRAGMA user_version=999'); db.close();
    final before = File(path).readAsBytesSync();
    expect(() => open(encryptionKey: key), throwsStateError);
    expect(File(path).readAsBytesSync(), before);
  });
  test('session and agent deletion stay scoped and remove archived decisions', () {
    final db = open(); seed(db, 'a'); seed(db, 'b');
    final a = const MemoryScope(agentId: 'a').key;
    final b = const MemoryScope(agentId: 'b').key;
    final sa = db.createSession(a, 'a'); final sb = db.createSession(b, 'b');
    db.appendSessionMessage(a, sa, 'user', 'SECRET_LAGON42', decision: true);
    db.writeCheckpoint(a, sa, 1, 'SECRET_LAGON42', 'compact');
    expect(() => db.deleteSession(b, sa), throwsStateError);
    db.deleteSession(a, sa);
    expect(db.contextSessions(a), isEmpty);
    expect(db.searchDecisions(a, 'a', 'SECRET_LAGON42'), isEmpty);
    expect(db.documents('a'), hasLength(1));
    db.deleteAgent('a');
    expect(db.agents().single.id, 'b');
    expect(db.documents('b'), hasLength(1));
    expect(db.contextSessions(b).single.id, sb);
    db.close();
  });
}
