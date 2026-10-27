import 'dart:collection';

import 'package:world_contracts/world_contracts.dart';

class GridPathfinder {
  List<GridPos>? findPath(WorldState s, GridPos start, GridPos goal) {
    final blocked = s.blockedCells.toSet();
    bool valid(GridPos p) =>
        p.x >= 0 &&
        p.y >= 0 &&
        p.x < s.config.width &&
        p.y < s.config.height &&
        !blocked.contains(p);
    if (!valid(start) || !valid(goal)) return null;
    final previous = <GridPos, GridPos?>{start: null},
        queue = Queue<GridPos>()..add(start);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      if (p == goal) {
        final path = <GridPos>[];
        GridPos? current = p;
        while (current != start) {
          path.add(current!);
          current = previous[current];
        }
        return path.reversed.toList();
      }
      for (final n in [
        GridPos(p.x, p.y - 1),
        GridPos(p.x + 1, p.y),
        GridPos(p.x, p.y + 1),
        GridPos(p.x - 1, p.y),
      ]) {
        if (valid(n) && !previous.containsKey(n)) {
          previous[n] = p;
          queue.add(n);
        }
      }
    }
    return null;
  }
}
