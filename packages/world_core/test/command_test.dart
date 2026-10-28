import 'package:test/test.dart';
import 'package:world_core/world_core.dart';

import 'support.dart';

ActionProposal cmd(
  WorldCore c, {
  String id = 'c1',
  String actor = 'a1',
  int? rev,
  int? expiry,
  ActionKind kind = ActionKind.move,
  Map<String, dynamic> args = const {'x': 2, 'y': 2},
}) => ActionProposal(
  commandId: id,
  worldId: 'world1',
  actorId: actor,
  expectedRevision: rev ?? c.snapshot().state.revision,
  issuedTick: c.snapshot().state.tick,
  expiresTick: expiry ?? c.snapshot().state.tick + 100,
  kind: kind,
  arguments: args,
);
void main() {
  test('route_avoids_obstacle', () {
    final p = GridPathfinder().findPath(
      fixtureCore().snapshot().state,
      const GridPos(2, 1),
      const GridPos(4, 1),
    );
    expect(p, isNotNull);
    expect(p, isNot(contains(const GridPos(3, 1))));
    expect(p!.last, const GridPos(4, 1));
  });
  test(
    'unreachable_returns_null',
    () => expect(
      GridPathfinder().findPath(
        fixtureCore().snapshot().state,
        const GridPos(1, 1),
        const GridPos(5, 5),
      ),
      isNull,
    ),
  );
  test('move_advances_one_cell_per_tick', () {
    final c = fixtureCore();
    c.submit(cmd(c));
    c.step(1);
    expect(c.snapshot().state.agents.first.position, const GridPos(2, 1));
    c.step(1);
    expect(c.snapshot().state.agents.first.position, const GridPos(2, 2));
  });
  test('rejects_stale_revision', () {
    final c = fixtureCore();
    expect(c.submit(cmd(c, rev: 99)).code, 'stale_revision');
  });
  test('rejects_paused', () {
    final c = fixtureCore()..setPaused(true);
    expect(c.submit(cmd(c)).code, 'paused');
  });
  test('rejects_expired', () {
    final c = fixtureCore()..step(2);
    expect(c.submit(cmd(c, expiry: 1)).code, 'expired');
  });
  test('replay_has_no_second_effect', () {
    final c = fixtureCore(), p = cmd(fixtureCore());
    c.submit(p);
    final s = c.snapshot();
    expect(c.submit(p).code, 'duplicate');
    expect(c.snapshot(), s);
  });
  test('missing_actor_rejected', () {
    final c = fixtureCore();
    expect(c.submit(cmd(c, actor: 'missing')).code, 'invalid_actor');
  });
}
