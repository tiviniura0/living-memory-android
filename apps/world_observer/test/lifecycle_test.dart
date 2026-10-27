import 'package:flutter/widgets.dart' show AppLifecycleState, SizedBox;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';
import 'package:world_observer/world_controller.dart';
import 'package:world_observer/runtime/world_lifecycle.dart';
import 'package:world_observer/world_app.dart';

class FullDisk extends FileOps {
  @override
  Future<void> writeFlushed(String path, String body) async =>
      throw const FileSystemException('disk full');
}

void main() {
  late Directory d;
  late WorldController c;
  setUp(() async {
    d = await Directory.systemTemp.createTemp('lifecycle-test');
    final core = WorldCore(WorldFactory.create('w', WorldConfig(), 5));
    c = WorldController(core, LocalAgentRunner(core), CheckpointStore(d));
  });
  tearDown(() async {
    c.dispose();
    await d.delete(recursive: true);
  });
  test('background_save_and_pause', () async {
    c.core.step(5);
    await WorldLifecycle(c).onState(AppLifecycleState.paused);
    expect(c.paused, isTrue);
    expect((await c.store.load()).snapshot!.state.tick, 5);
  });
  test('resume_no_walltime_catchup', () async {
    await WorldLifecycle(c).onState(AppLifecycleState.paused);
    final tick = c.core.snapshot().state.tick;
    await WorldLifecycle(c).onState(AppLifecycleState.resumed);
    expect(c.core.snapshot().state.tick, tick);
    expect(c.paused, isTrue);
  });
  testWidgets('disk_full_keeps_ui_usable', (t) async {
    final core = WorldCore(WorldFactory.create('w', WorldConfig(), 5));
    final broken = WorldController(
      core,
      LocalAgentRunner(core),
      CheckpointStore(d, files: FullDisk()),
    );
    await t.pumpWidget(WorldApp(controller: broken));
    await broken.save();
    await t.pump();
    expect(find.textContaining('Sauvegarde impossible'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    broken.dispose();
  });
}
