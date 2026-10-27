import 'package:world_contracts/world_contracts.dart';

import 'world_rng.dart';

class WorldFactory {
  static WorldState create(String id, WorldConfig config, int population) {
    if (population < 0 ||
        population > config.populationMax ||
        population > config.width * config.height)
      throw ArgumentError('Population');
    final rng = WorldRng(config.seed), blocked = <Map<String, int>>[];
    // Keep the village clearing and its nearby food accessible; distant rocks are seeded.
    for (var y = 8; y < config.height; y++) {
      for (var x = 8; x < config.width; x++) {
        if (rng.nextUint32() % 19 == 0) blocked.add(GridPos(x, y).toJson());
      }
    }
    final agents = [
      for (var i = 0; i < population; i++)
        AgentState(
          id: 'a${i + 1}',
          name: 'Habitant ${i + 1}',
          position: GridPos(i % config.width, i ~/ config.width),
        ).toJson(),
    ];
    final s = WorldState({
      'worldId': id,
      'config': config.toJson(),
      'tick': 0,
      'revision': 0,
      'rngState': rng.state,
      'agents': agents,
      'resources': [
        {
          'id': 'food1',
          'position': GridPos(config.width > 2 ? 2 : 0, 0).toJson(),
          'food': 100,
          'reservationAgentId': null,
          'reservationUntilTick': null,
        },
      ],
      'blockedCells': blocked,
      'appliedCommandIds': [],
      'pendingActions': [],
      'schedulerCursor': 0,
      'decisionSequence': 0,
      'eventLog': [],
    });
    WorldCodec.validate(s.toJson());
    return s;
  }
}
