import 'package:test/test.dart';
import 'package:world_core/world_core.dart';

import 'support.dart';

void main() {
  test('same_seed_same_map', () {
    final a = WorldFactory.create('w', WorldConfig(), 5);
    expect(a.agents.length, 5);
    expect(a, WorldFactory.create('w', WorldConfig(), 5));
  });
  test('restored_rng_same_sequence', () {
    final r = WorldRng(1);
    expect(r.nextUint32(), 270369);
    final b = WorldRng(r.state);
    expect(r.nextUint32(), b.nextUint32());
  });
  test('paused_step_preserves_state', () {
    final c = fixtureCore()..setPaused(true);
    final s = c.snapshot();
    c.step(40);
    expect(c.snapshot(), s);
    c.setPaused(false);
    c.step(40);
    expect(c.snapshot().state.tick, 40);
  });
  test('lower_cap_keeps_agents', () {
    final c = fixtureCore();
    expect(c.setPopulationMax(2).status, ActionStatus.applied);
    expect(c.snapshot().state.agents.length, 5);
    expect(c.snapshot().state.config.populationMax, 2);
  });
  test('add_over_cap_rejected', () {
    final c = fixtureCore()..setPopulationMax(2);
    expect(
      c
          .addAgent(
            AgentState(
              id: 'extra',
              name: 'Extra',
              position: const GridPos(1, 1),
            ),
          )
          .status,
      ActionStatus.rejected,
    );
  });
  test('invalid_tick_count_rejected', () {
    expect(() => fixtureCore().step(-1), throwsRangeError);
    expect(() => fixtureCore().step(1001), throwsRangeError);
  });
}
