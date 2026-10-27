import 'package:test/test.dart';
import 'package:agent_runtime/agent_runtime.dart';

import '../../../apps/world_observer/lib/runtime/world_loop.dart';

WorldLoop loop() {
  final c = WorldCore(WorldFactory.create('w', WorldConfig(), 5));
  return WorldLoop(SimulationRunner(c, LocalAgentRunner(c)));
}

void main() {
  test('max_8_ticks_per_frame', () {
    final l = loop();
    expect(l.advance(const Duration(seconds: 20)), 8);
    expect(l.runner.core.snapshot().state.tick, 8);
    expect(l.advance(Duration.zero), 8);
  });
  test('pause_zero_tick', () {
    final l = loop()..setPaused(true);
    expect(l.advance(const Duration(seconds: 20)), 0);
  });
  test('resume_no_walltime_catchup', () {
    final l = loop();
    l.advance(const Duration(milliseconds: 200));
    l.setPaused(true);
    l.advance(const Duration(hours: 1));
    l.setPaused(false);
    expect(l.advance(const Duration(milliseconds: 100)), 0);
  });
  test('reports_slow_actual_speed', () {
    final l = loop()..setSpeed(4);
    l.advance(const Duration(seconds: 2));
    expect(l.effectiveSpeed, 1);
  });
}
