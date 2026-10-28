import 'dart:io';

import 'package:test/test.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

import '../../../apps/world_observer/lib/runtime/lifecycle_logic.dart';

void main() {
  test('background_save_and_pause_real_core_and_disk', () async {
    final d = await Directory.systemTemp.createTemp('lifecycle-core');
    try {
      final c = WorldCore(WorldFactory.create('w', WorldConfig(), 5))..step(5),
          store = CheckpointStore(d);
      final lifecycle = LifecyclePause(
        c.setPaused,
        () => store.save(c.snapshot()),
      );
      await lifecycle.background();
      expect(c.paused, isTrue);
      expect((await store.load()).snapshot!.state.tick, 5);
    } finally {
      await d.delete(recursive: true);
    }
  });
  test('resume_stays_paused_without_catchup', () async {
    final c = WorldCore(WorldFactory.create('w', WorldConfig(), 5));
    final l = LifecyclePause(c.setPaused, () async {});
    await l.background();
    l.resume();
    c.step(5);
    expect(c.paused, isTrue);
    expect(c.snapshot().state.tick, 0);
  });
}
