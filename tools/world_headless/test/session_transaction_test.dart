import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

import '../../../apps/world_observer/lib/runtime/world_session.dart';

class FaultFiles extends FileOps {
  bool fail = false, hold = false;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> writeFlushed(String path, String body) async {
    if (fail) throw const FileSystemException('disk full');
    if (hold &&
        path.endsWith('.json.tmp') &&
        !path.endsWith('manifest.json.tmp')) {
      hold = false;
      entered.complete();
      await release.future;
    }
    await super.writeFlushed(path, body);
  }
}

void main() {
  test('host_records_real_tick_diagnostics', () {
    final c = WorldCore(WorldFactory.create('w', WorldConfig(), 5));
    final s = WorldSession(
      c,
      LocalAgentRunner(c),
      CheckpointStore(Directory('unused-metrics')),
    );
    s.advance(const Duration(seconds: 1));
    expect(s.metrics.sampleCount, 1);
    expect(s.metrics.samples.single['agents'], 5);
    expect(s.metrics.samples.single['tickMicros'], greaterThanOrEqualTo(0));
  });
  late Directory directory;
  late FaultFiles files;
  late WorldSession session;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('session-test');
    files = FaultFiles();
    final c = WorldCore(WorldFactory.create('old', WorldConfig(), 5));
    session = WorldSession(
      c,
      LocalAgentRunner(c),
      CheckpointStore(directory, files: files),
    );
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('failed_export_never_returns_stale_checkpoint', () async {
    await session.save();
    session.core.step(1);
    files.fail = true;
    await expectLater(session.exportJson(), throwsStateError);
    expect((await session.store.load()).snapshot!.state.tick, 0);
  });
  test('background_save_during_import_keeps_imported_world', () async {
    await session.save();
    final incoming = WorldFactory.create('imported', WorldConfig(), 5);
    files.hold = true;
    final importing = session.importJson(WorldCodec.encode(incoming));
    await files.entered.future;
    final saving = session.save();
    files.release.complete();
    await Future.wait([importing, saving]);
    expect(session.core.snapshot().state.worldId, 'imported');
    expect((await session.store.load()).snapshot!.state.worldId, 'imported');
  });
  test('lowered_cap_import_requires_and_uses_consent', () async {
    final data = WorldFactory.create('imported', WorldConfig(), 5).toJson();
    data['config']['populationMax'] = 2;
    var confirmations = 0;
    await session.importWithConsent(WorldCodec.encode(WorldState(data)), (
      cap,
      count,
    ) async {
      confirmations++;
      expect(cap, 2);
      expect(count, 5);
      return true;
    });
    expect(confirmations, 1);
    expect(session.core.snapshot().state.worldId, 'imported');
    expect(session.core.snapshot().state.config.populationMax, 5);
  });
  test('declined_cap_override_keeps_world', () async {
    final data = WorldFactory.create('imported', WorldConfig(), 5).toJson();
    data['config']['populationMax'] = 2;
    var confirmations = 0;
    await session.importWithConsent(WorldCodec.encode(WorldState(data)), (
      cap,
      count,
    ) async {
      confirmations++;
      return false;
    });
    expect(confirmations, 1);
    expect(session.core.snapshot().state.worldId, 'old');
  });
}
