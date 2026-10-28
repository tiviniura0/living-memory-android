import 'package:test/test.dart';
import 'package:world_core/world_core.dart';

import 'support.dart';
import 'command_test.dart' show cmd;

void main() {
  test('metabolism_after_40_ticks', () {
    final c = fixtureCore()..step(40);
    expect(c.snapshot().state.agents.first.hunger, 61);
    expect(c.snapshot().state.agents.first.energy, 79);
  });
  test('clamp_needs', () {
    final c = fixtureCore();
    for (var i = 0; i < 10; i++) c.step(1000);
    expect(c.snapshot().state.agents.first.hunger, 100);
    expect(c.snapshot().state.agents.first.energy, 0);
  });
  test('rest_recovers_four_after_40', () {
    final c = fixtureCore();
    expect(
      c.submit(cmd(c, kind: ActionKind.rest, args: {})).status,
      ActionStatus.pending,
    );
    c.step(40);
    expect(c.snapshot().state.agents.first.energy, 84);
  });
  test('two_agents_last_food_once', () {
    final c = fixtureCore();
    c.submit(cmd(c, kind: ActionKind.gather, args: {'resourceId': 'food1'}));
    final r = c.submit(
      cmd(
        c,
        id: 'c2',
        actor: 'a2',
        kind: ActionKind.gather,
        args: {'resourceId': 'food1'},
      ),
    );
    expect(r.code, 'unavailable_resource');
    c.step(4);
    expect(c.snapshot().state.resources.first.food, 0);
    expect(
      c.snapshot().state.agents.fold<int>(0, (n, a) => n + a.inventoryFood),
      1,
    );
  });
  test('consume_without_food_rejected', () {
    final c = fixtureCore();
    expect(
      c.submit(cmd(c, kind: ActionKind.consume, args: {})).code,
      'insufficient_inventory',
    );
  });
  test('busy_actor_rejected', () {
    final c = fixtureCore();
    c.submit(cmd(c, kind: ActionKind.gather, args: {'resourceId': 'food1'}));
    expect(c.submit(cmd(c, id: 'c2')).code, 'actor_busy');
  });
  test('gather_then_consume', () {
    final c = fixtureCore();
    c.submit(cmd(c, kind: ActionKind.gather, args: {'resourceId': 'food1'}));
    c.step(4);
    expect(c.snapshot().state.agents.first.inventoryFood, 1);
    c.submit(cmd(c, id: 'c2', kind: ActionKind.consume, args: {}));
    expect(c.snapshot().state.agents.first.hunger, 20);
    expect(c.snapshot().state.agents.first.inventoryFood, 0);
  });
  test('deleted_resource_late_action_rejected', () {
    final c = fixtureCore();
    final before = c.snapshot();
    expect(
      c
          .submit(cmd(c, kind: ActionKind.gather, args: {'resourceId': 'gone'}))
          .code,
      'unavailable_resource',
    );
    expect(c.snapshot(), before);
  });
}
