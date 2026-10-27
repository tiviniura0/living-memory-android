import 'package:agent_runtime/agent_runtime.dart';
export 'package:agent_runtime/agent_runtime.dart';

class ScenarioRunner {
  WorldSnapshot run(WorldState initial, int ticks) {
    if (ticks < 0 || ticks > 1000000) throw RangeError('ticks');
    final c = WorldCore(initial);
    // One core is authoritative in both hosts.
    final runner = SimulationRunner(c, LocalAgentRunner(c));
    for (var left = ticks; left > 0;) {
      final n = left > 1000 ? 1000 : left;
      runner.advance(n);
      left -= n;
    }
    return c.snapshot();
  }
}
