import 'package:world_core/world_core.dart';
export 'package:world_core/world_core.dart';

class AgentObservation {
  final WorldSnapshot snapshot;
  final AgentState agent;
  final List<ResourceState> resources;
  final List<AgentState> agents;
  final List<WorldEvent> events;
  AgentObservation(
    this.snapshot,
    this.agent,
    this.resources,
    this.agents,
    this.events,
  );
}

class Perception {
  static AgentObservation forAgent(WorldSnapshot s, String id) {
    final own = s.state.agents.firstWhere((a) => a.id == id);
    final resources = s.state.resources
            .where((r) => r.position.distance(own.position) <= 6)
            .toList(),
        agents = s.state.agents
            .where((a) => a.position.distance(own.position) <= 6)
            .toList(),
        events = s.state.eventLog
            .where((e) => e.observedBy.contains(id))
            .toList();
    final data = s.state.toJson();
    data['agents'] = agents.map((a) => a.toJson()).toList();
    data['resources'] = resources.map((r) => r.toJson()).toList();
    data['eventLog'] = events.map((e) => e.toJson()).toList();
    data['blockedCells'] = s.state.blockedCells
        .where((p) => p.distance(own.position) <= 6)
        .map((p) => p.toJson())
        .toList();
    data['pendingActions'] = [];
    data['appliedCommandIds'] = [];
    return AgentObservation(
      WorldSnapshot(WorldState(data)),
      own,
      List.unmodifiable(resources),
      List.unmodifiable(agents),
      List.unmodifiable(events),
    );
  }
}

class LocalPolicy {
  ActionProposal? propose(AgentObservation o) {
    final a = o.agent, s = o.snapshot.state;
    if (a.currentAction != null || a.nextDecisionTick > s.tick) return null;
    ActionProposal action(
      ActionKind k, [
      Map<String, dynamic> args = const {},
    ]) => ActionProposal(
      commandId: 'proposal',
      worldId: s.worldId,
      actorId: a.id,
      expectedRevision: s.revision,
      issuedTick: s.tick,
      expiresTick: s.tick + 8,
      kind: k,
      arguments: args,
    );
    if (a.energy <= 30) return action(ActionKind.rest);
    if (a.hunger >= 60) {
      if (a.inventoryFood > 0) return action(ActionKind.consume);
      final food =
          o.resources
              .where((r) => r.food > 0 && r.reservationAgentId == null)
              .toList()
            ..sort((x, y) {
              final c = x.position
                  .distance(a.position)
                  .compareTo(y.position.distance(a.position));
              return c != 0 ? c : x.id.compareTo(y.id);
            });
      for (final r in food) {
        if (r.position.distance(a.position) <= 1)
          return action(ActionKind.gather, {'resourceId': r.id});
        if (GridPathfinder().findPath(s, a.position, r.position) != null)
          return action(ActionKind.move, r.position.toJson());
      }
      return null;
    }
    final dirs = [
      GridPos(a.position.x, a.position.y - 1),
      GridPos(a.position.x + 1, a.position.y),
      GridPos(a.position.x, a.position.y + 1),
      GridPos(a.position.x - 1, a.position.y),
    ];
    final offset = (s.tick + a.id.codeUnits.fold<int>(0, (n, c) => n + c)) % 4;
    for (var i = 0; i < 4; i++) {
      final p = dirs[(i + offset) % 4];
      final path = GridPathfinder().findPath(s, a.position, p);
      if (path != null) return action(ActionKind.move, p.toJson());
    }
    return null;
  }
}

class LocalAgentRunner {
  final WorldCore core;
  final LocalPolicy policy;
  LocalAgentRunner(this.core, {LocalPolicy? policy})
    : policy = policy ?? LocalPolicy();
  List<ActionResult> decideRound() {
    if (core.paused) return [];
    final s = core.snapshot().state, agents = s.agents;
    final results = <ActionResult>[];
    for (var i = 0; i < agents.length; i++) {
      final id = agents[(i + s.schedulerCursor) % agents.length].id;
      final own = core.snapshot().state.agents.firstWhere((a) => a.id == id);
      if (own.currentAction != null ||
          own.nextDecisionTick > core.snapshot().state.tick)
        continue;
      final p = policy.propose(Perception.forAgent(core.snapshot(), id));
      if (p == null) {
        core.recordFailure(id, 'no_local_action');
        continue;
      }
      final commandId = core.issueCommandId(id),
          current = core.snapshot().state;
      final result = core.submit(
        ActionProposal(
          commandId: commandId,
          worldId: current.worldId,
          actorId: id,
          expectedRevision: current.revision,
          issuedTick: current.tick,
          expiresTick: current.tick + 8,
          kind: p.kind,
          arguments: p.arguments,
        ),
      );
      results.add(result);
      if (result.status == ActionStatus.rejected)
        core.recordFailure(id, result.code);
    }
    core.finishDecisionRound();
    return List.unmodifiable(results);
  }
}

class SimulationRunner {
  final WorldCore core;
  final LocalAgentRunner agents;
  SimulationRunner(this.core, this.agents);
  List<WorldEvent> advance(int ticks) {
    RangeError.checkValueInInterval(ticks, 0, 1000);
    final events = <WorldEvent>[];
    for (var i = 0; i < ticks; i++) {
      if (core.paused) break;
      for (final r in agents.decideRound()) events.addAll(r.events);
      events.addAll(core.step(1));
    }
    return List.unmodifiable(events);
  }
}
