import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

class FailRename extends FileOps {
  bool fail = false;
  @override
  Future<void> rename(String from, String to) async {
    if (fail && to.endsWith('manifest.json'))
      throw const FileSystemException('disk full');
    await super.rename(from, to);
  }
}

void main() {
  late Directory d;
  late CheckpointStore store;
  late WorldCore c;
  setUp(() async {
    d = await Directory.systemTemp.createTemp('world-test');
    store = CheckpointStore(d);
    c = WorldCore(WorldFactory.create('world1', WorldConfig(), 5));
  });
  tearDown(() async {
    await d.delete(recursive: true);
  });
  test('roundtrip_mid_action', () async {
    SimulationRunner(c, LocalAgentRunner(c)).advance(2);
    final s = c.snapshot();
    await store.save(s);
    expect((await CheckpointStore(d).load()).snapshot, s);
  });
  test('interrupted_before_manifest_uses_previous', () async {
    await store.save(c.snapshot());
    final old = c.snapshot();
    c.step(1);
    final f = FailRename()..fail = true;
    await expectLater(
      CheckpointStore(d, files: f).save(c.snapshot()),
      throwsA(isA<FileSystemException>()),
    );
    expect((await store.load()).snapshot, old);
  });
  test('corrupt_latest_falls_back', () async {
    await store.save(c.snapshot());
    final old = c.snapshot();
    c.step(1);
    await store.save(c.snapshot());
    final files =
        d
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'checkpoint-\d+.json$').hasMatch(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    await files.last.writeAsString('broken');
    final r = await store.load();
    expect(r.snapshot, old);
    expect(r.recovered, isTrue);
  });
  test('future_import_preserves_world', () async {
    await store.save(c.snapshot());
    final data = c.snapshot().state.toJson();
    data['config']['schemaVersion'] = 2;
    await expectLater(
      store.importJson(jsonEncode(data)),
      throwsFormatException,
    );
    expect((await store.load()).snapshot, c.snapshot());
  });
  test('duplicate_id_import_rejected', () async {
    final data = c.snapshot().state.toJson();
    data['agents'].add(data['agents'][0]);
    await expectLater(
      store.importJson(jsonEncode(data)),
      throwsFormatException,
    );
  });
  test('oversized_import_rejected', () async {
    await expectLater(
      store.importJson(' ' * (16 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
  });
  test('lower_cap_export_import_roundtrip_with_explicit_override', () async {
    c.setPopulationMax(2);
    await store.save(c.snapshot());
    expect((await store.load()).snapshot, c.snapshot());
    final json = await store.exportJson();
    await expectLater(store.importJson(json), throwsFormatException);
    final r = await store.importJson(json, populationMaxOverride: 5);
    expect(r.snapshot!.state.agents.length, 5);
    expect(r.snapshot!.state.config.populationMax, 5);
  });
  test('event_log_and_observedBy_survive_restore', () async {
    SimulationRunner(c, LocalAgentRunner(c)).advance(5);
    await store.save(c.snapshot());
    expect(
      (await store.load()).snapshot!.state.eventLog,
      c.snapshot().state.eventLog,
    );
    expect(c.snapshot().state.eventLog.first.observedBy, isNotEmpty);
  });
}
