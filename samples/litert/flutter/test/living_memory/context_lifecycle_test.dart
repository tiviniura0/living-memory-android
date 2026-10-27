import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/context_lifecycle_manager.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';

void main() {
  late Directory dir;
  late MemoryStore store;
  const scope = MemoryScope(agentId: 'aru');
  setUp(() {
    dir = Directory.systemTemp.createTempSync('context-');
    store = MemoryStore.open('${dir.path}/m.db', profile: 'test', dimension: 2);
    store.createAgent('aru', 'Aru');
  });
  tearDown(() { store.close(); dir.deleteSync(recursive: true); });
  test('compaction preserves originals and decisions across reopen', () {
    final manager = ContextLifecycleManager(store, scope, tokenBudget: 256);
    final id = manager.startSession();
    manager.append(id, 'user', 'Décision : conserver les données.', decision: true);
    manager.append(id, 'assistant', 'Affirmation générée non vérifiée.');
    manager.append(id, 'user', 'suite ' * 80);
    expect(manager.needsCompaction(id), isTrue);
    final checkpoint = manager.compact(id);
    expect(checkpoint.summary, contains('conserver les données'));
    expect(checkpoint.summary, isNot(contains('Affirmation générée')));
    expect(manager.messages(id), hasLength(3));
    store.close();
    store = MemoryStore.open('${dir.path}/m.db', profile: 'test', dimension: 2);
    final restored = ContextLifecycleManager(store, scope, tokenBudget: 256);
    expect(restored.checkpoints(id).single.summary, checkpoint.summary);
    expect(restored.messages(id), hasLength(3));
    expect(store.memories('aru'), isEmpty);
  });
  test('scope mismatch cannot restore or write a session', () {
    final a = ContextLifecycleManager(store, scope);
    final id = a.startSession();
    final b = ContextLifecycleManager(store, const MemoryScope(agentId: 'aru', projectId: 'other'));
    expect(b.sessions(), isEmpty);
    expect(() => b.messages(id), throwsStateError);
    expect(() => b.append(id, 'user', 'injection'), throwsStateError);
    expect(() => a.append(id, 'tool', 'model claims tool ran'), throwsArgumentError);
  });
  test('oversized input is refused and repeated compaction is idempotent', () {
    final manager = ContextLifecycleManager(store, scope, tokenBudget: 256);
    final id = manager.startSession();
    expect(() => manager.append(id, 'user', 'x' * 20001), throwsArgumentError);
    manager.append(id, 'user', 'Décision explicite', decision: true);
    final a = manager.compact(id);
    final b = manager.compact(id);
    expect(a.id, b.id);
    expect(manager.checkpoints(id), hasLength(1));
    expect(manager.activeTokenEstimate(id), lessThan(256));
  });
  test('compaction after reset and changed decisions appends a fresh checkpoint', () {
    final manager = ContextLifecycleManager(store, scope);
    final id = manager.startSession();
    manager.append(id, 'user', 'Décision A');
    manager.compact(id);
    manager.resetActiveContext(id);
    manager.markDecision(id, 1, decision: true);
    final revised = manager.compact(id);
    expect(manager.checkpoints(id).last.id, revised.id);
    expect(manager.checkpoints(id), hasLength(3));
    expect(revised.summary, contains('décision utilisateur'));
  });
  test('reset retains originals and permanent documents', () {
    final doc = store.addDocument(agentId: 'aru', name: 'note', digest: 'a',
      chunks: [const MemoryChunk(page: 1, ordinal: 1, text: 'Permanent')], vectors: [[1, 0]]);
    final manager = ContextLifecycleManager(store, scope);
    final id = manager.startSession();
    manager.append(id, 'user', 'Décision', decision: true);
    manager.compact(id);
    manager.resetActiveContext(id);
    expect(manager.messages(id), hasLength(1));
    expect(manager.checkpoints(id), hasLength(2));
    expect(store.documents('aru').single.id, doc);
  });
}
