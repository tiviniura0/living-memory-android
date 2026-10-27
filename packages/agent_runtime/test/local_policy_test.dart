import 'package:test/test.dart';
import 'package:agent_runtime/agent_runtime.dart';

WorldCore village() =>
    WorldCore(WorldFactory.create('world1', WorldConfig(), 5));
void main() {
  test('energy_urgent_before_hunger', () {
    final s = village().snapshot().state.toJson();
    s['agents'][0]['energy'] = 30;
    expect(
      LocalPolicy()
          .propose(Perception.forAgent(WorldSnapshot(WorldState(s)), 'a1'))
          ?.kind,
      ActionKind.rest,
    );
  });
  test('hungry_seeks_food', () {
    expect(
      LocalPolicy()
          .propose(Perception.forAgent(village().snapshot(), 'a1'))
          ?.kind,
      ActionKind.move,
    );
  });
  test('no_secret_outside_perception', () {
    final s = village().snapshot().state.toJson();
    s['resources'][0]['position'] = {'x': 50, 'y': 50};
    expect(
      Perception.forAgent(WorldSnapshot(WorldState(s)), 'a1').resources,
      isEmpty,
    );
  });
  test('all_agents_get_turns', () {
    final c = village();
    final r = LocalAgentRunner(c);
    for (var i = 0; i < 100; i++) {
      r.decideRound();
      c.step(1);
    }
    expect(c.snapshot().state.decisionSequence, greaterThanOrEqualTo(5));
    expect(
      c.snapshot().state.agents.every(
        (a) =>
            a.currentAction != null ||
            a.nextDecisionTick > 0 ||
            a.inventoryFood > 0 ||
            a.hunger < 60,
      ),
      isTrue,
    );
  });
  test('batched_ticks_match_single_ticks', () {
    final a = village(), b = village();
    SimulationRunner(a, LocalAgentRunner(a)).advance(100);
    final r = SimulationRunner(b, LocalAgentRunner(b));
    for (var i = 0; i < 100; i++) r.advance(1);
    expect(a.snapshot(), b.snapshot());
    expect(a.snapshot().state.tick, 100);
  });
  test('restored_sequence_preserves_ids', () {
    final a = village();
    SimulationRunner(a, LocalAgentRunner(a)).advance(5);
    final b = WorldCore(
      WorldCodec.decode(WorldCodec.encode(a.snapshot().state)),
    );
    SimulationRunner(a, LocalAgentRunner(a)).advance(10);
    SimulationRunner(b, LocalAgentRunner(b)).advance(10);
    expect(a.snapshot(), b.snapshot());
  });
  test('unreachable_waits_40_ticks', () {
    final s = village().snapshot().state.toJson();
    s['resources'] = [];
    final c = WorldCore(WorldState(s));
    LocalAgentRunner(c).decideRound();
    expect(c.snapshot().state.agents.first.nextDecisionTick, 40);
  });
  test('collect_consume_and_rest_observable', () {
    final s = village().snapshot().state.toJson();
    s['agents'][1]['energy'] = 30;
    final c = WorldCore(WorldState(s));
    SimulationRunner(c, LocalAgentRunner(c)).advance(100);
    expect(
      c.snapshot().state.eventLog.map((e) => e.kind),
      containsAll(['collected', 'consumed', 'rested']),
    );
  });
}
