import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_memory_core/living_memory_core.dart';
import 'package:living_world_memory/living_world_memory.dart';
import 'package:world_persistence/world_persistence.dart';

void main() {
  const key =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  late Directory dir;
  late MemoryStore store;
  late LivingWorldMemory memory;
  void open() {
    store = MemoryStore.open(
      '${dir.path}/memory.db',
      profile: 'test',
      dimension: 2,
      encryptionKey: key,
    );
    memory = LivingWorldMemory(
      store: store,
      worldId: 'world1',
      agentIds: {'a1', 'a2'},
      embed: (_) async => [1, 0],
    );
  }

  PerceivedEvent event(
    String id,
    String text, {
    String agent = 'a1',
    String world = 'world1',
    List<String>? observers,
  }) => PerceivedEvent({
    'schemaVersion': 1,
    'worldId': world,
    'agentId': agent,
    'eventId': id,
    'tick': 1,
    'sourceRevision': 1,
    'kind': 'observation',
    'text': text,
    'parentEventIds': <String>[],
    'observedBy': observers ?? [agent],
  });
  Future<List<MemoryReference>> recall(String agent, String text) =>
      memory.recall(
        RecallQuery({
          'schemaVersion': 1,
          'worldId': 'world1',
          'agentId': agent,
          'text': text,
          'topK': 20,
          'contextBudgetBytes': 10000,
        }),
      );
  setUp(() {
    dir = Directory.systemTemp.createTempSync('world-memory-');
    open();
  });
  tearDown(() {
    store.close();
    dir.deleteSync(recursive: true);
  });

  test(
    'private memories persist without leaking between two L1 agents',
    () async {
      await memory.ingest(event('e1', 'SECRET_LAGON42'));
      expect(
        (await recall('a1', 'SECRET_LAGON42')).single.data['text'],
        'SECRET_LAGON42',
      );
      expect(await recall('a2', 'SECRET_LAGON42'), isEmpty);
      store.close();
      open();
      expect(await recall('a1', 'SECRET_LAGON42'), hasLength(1));
      expect(await recall('a2', 'SECRET_LAGON42'), isEmpty);
      expect(
        String.fromCharCodes(File('${dir.path}/memory.db').readAsBytesSync()),
        isNot(contains('SECRET_LAGON42')),
      );
    },
  );
  test(
    'event retries are idempotent and conflicting data is refused',
    () async {
      final first = await memory.ingest(event('e1', 'lagon'));
      expect(first.data['status'], 'accepted');
      expect(
        (await memory.ingest(event('e1', 'lagon'))).data['status'],
        'already_present',
      );
      await expectLater(
        memory.ingest(event('e1', 'autre')),
        throwsA(isA<FormatException>()),
      );
      expect(await recall('a1', 'lagon'), hasLength(1));
    },
  );
  test('unperceived and foreign scope rejected before embedding', () async {
    var embeds = 0;
    memory = LivingWorldMemory(
      store: store,
      worldId: 'world1',
      agentIds: {'a1', 'a2'},
      embed: (_) async {
        embeds++;
        return [1, 0];
      },
    );
    await expectLater(
      memory.ingest(event('e1', 'secret', observers: ['a2'])),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      memory.ingest(event('e2', 'secret', world: 'other')),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      memory.ingest(event('e3', 'secret', agent: 'foreign')),
      throwsA(isA<FormatException>()),
    );
    expect(embeds, 0);
  });
  test(
    'explicit sharing reaches named recipient then revocation removes access',
    () async {
      final ack = await memory.ingest(event('e1', 'La source du lagon'));
      final source = ack.data['sourceId'] as String;
      await memory.publish(agentId: 'a1', sourceId: source, recipients: {'a2'});
      expect(
        (await recall('a2', 'lagon')).single.data['status'],
        'shared_observation',
      );
      await memory.revoke(agentId: 'a1', sourceId: source);
      expect(await recall('a2', 'lagon'), isEmpty);
      expect(await recall('a1', 'lagon'), hasLength(1));
      await memory.delete(ScopedMemoryId('world1', 'a1', source));
      expect(await recall('a1', 'lagon'), isEmpty);
    },
  );
  test('real L1 simulation checkpoint feeds perceived events and retries after reopen', () async {
    final state = WorldCodec.decode(
      File('../../../fixtures/world/l1_world.json').readAsStringSync(),
    );
    final core = WorldCore(state);
    SimulationRunner(core, LocalAgentRunner(core)).advance(12);
    final checkpoint = CheckpointStore(Directory('${dir.path}/world'));
    await checkpoint.save(core.snapshot());
    final snapshot = (await checkpoint.load()).snapshot!;
    expect(snapshot.state.tick, 12);
    await memory.ingestSnapshot(snapshot);
    final count = (await recall('a1', 'move')).length;
    expect(count, greaterThan(0));
    store.close();
    open();
    await memory.ingestSnapshot(snapshot);
    expect((await recall('a1', 'move')).length, count);
    expect(snapshot, core.snapshot());
  });
  test(
    'concurrent adapter ingestion rejects conflicting receipt after embedding',
    () async {
      final firstEmbedding = Completer<List<double>>();
      final secondEmbedding = Completer<List<double>>();
      final first = LivingWorldMemory(
        store: store,
        worldId: 'world1',
        agentIds: {'a1', 'a2'},
        embed: (_) => firstEmbedding.future,
      );
      final second = LivingWorldMemory(
        store: store,
        worldId: 'world1',
        agentIds: {'a1', 'a2'},
        embed: (_) => secondEmbedding.future,
      );
      final a = first.ingest(event('race', 'lagon'));
      final b = second.ingest(event('race', 'different'));
      await Future<void>.delayed(Duration.zero);
      firstEmbedding.complete([1, 0]);
      await a;
      final refused = expectLater(b, throwsA(isA<FormatException>()));
      secondEmbedding.complete([1, 0]);
      await refused;
      expect(
        store.documents(
          memoryAgentKey('world1', 'a1'),
          projectId: 'living-world',
          worldId: 'world1',
        ),
        hasLength(1),
      );
    },
  );
  test(
    'revocation during another adapter recall prevents late disclosure',
    () async {
      final ack = await memory.ingest(event('race', 'SECRET_RACE'));
      final source = ack.data['sourceId'] as String;
      await memory.publish(agentId: 'a1', sourceId: source, recipients: {'a2'});
      final embedding = Completer<List<double>>();
      final reader = LivingWorldMemory(
        store: store,
        worldId: 'world1',
        agentIds: {'a1', 'a2'},
        embed: (_) => embedding.future,
      );
      final result = reader.recall(
        RecallQuery({
          'schemaVersion': 1,
          'worldId': 'world1',
          'agentId': 'a2',
          'text': 'SECRET_RACE',
          'topK': 20,
          'contextBudgetBytes': 10000,
        }),
      );
      await Future<void>.delayed(Duration.zero);
      await memory.revoke(agentId: 'a1', sourceId: source);
      embedding.complete([1, 0]);
      expect(await result, isEmpty);
    },
  );

  test(
    'retrieval query embedding is distinct from document embedding',
    () async {
      final adapter = Function.apply(LivingWorldMemory.new, [], {
        #store: store,
        #worldId: 'world1',
        #agentIds: {'a1', 'a2'},
        #embed: (String text) async =>
            text == 'Lagon42' ? <double>[1, 0] : <double>[0, 1],
        #embedQuery: (String text) async => <double>[1, 0],
      }) as LivingWorldMemory;
      await adapter.ingest(event('query-role', 'Lagon42'));
      final hits = await adapter.recall(
        RecallQuery({
          'schemaVersion': 1,
          'worldId': 'world1',
          'agentId': 'a1',
          'text': 'Où est la source ?',
          'topK': 3,
          'contextBudgetBytes': 1000,
        }),
      );
      expect(hits.single.data['text'], 'Lagon42');
    },
  );
  test('restored worlds require fresh sharing permission while source is unchanged', () async {
    final ack = await memory.ingest(event('transfer-permission', 'PRIVATE_RESTORED_LAGOON'));
    final source = ack.data['sourceId'] as String;
    await memory.publish(agentId:'a1',sourceId:source,recipients:{'a2'});
    expect(await recall('a2','PRIVATE_RESTORED_LAGOON'),hasLength(1));
    final recovery = MemoryBackup.generateRecoveryKey();
    final device = MemoryBackup.generateRecoveryKey();
    final archive = '${dir.path}/world.lmemory';
    final candidate = '${dir.path}/restored.db';
    MemoryBackup.exportEncrypted(sourcePath:'${dir.path}/memory.db',sourceKey:key,
      targetPath:archive,recoveryKey:recovery,profile:'test',dimension:2);
    MemoryBackup.restoreEncrypted(sourcePath:archive,recoveryKey:recovery,
      targetPath:candidate,deviceKey:device,profile:'test',dimension:2);
    final restored = MemoryStore.open(candidate,encryptionKey:device,profile:'test',dimension:2);
    try {
      final adapter = LivingWorldMemory(store:restored,worldId:'world1',agentIds:{'a1','a2'},embed:(_) async => [1,0]);
      Future<List<MemoryReference>> read(String agent) => adapter.recall(RecallQuery({
        'schemaVersion':1,'worldId':'world1','agentId':agent,'text':'PRIVATE_RESTORED_LAGOON',
        'topK':20,'contextBudgetBytes':10000}));
      expect(await read('a2'),isEmpty,reason:'Restoration must not reactivate sharing permissions');
      expect(await read('a1'),hasLength(1));
      expect(await recall('a2','PRIVATE_RESTORED_LAGOON'),hasLength(1),reason:'The live source keeps its existing approval');
      await adapter.publish(agentId:'a1',sourceId:source,recipients:{'a2'});
      expect(await read('a2'),hasLength(1));
    } finally { restored.close(); }
  });
}
