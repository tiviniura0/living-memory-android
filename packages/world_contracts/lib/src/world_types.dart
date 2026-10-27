import 'dart:convert';
import 'dart:collection';

import 'package:collection/collection.dart';

Object? freeze(Object? v) {
  if (v is UnmodifiableMapView || v is UnmodifiableListView) return v;
  if (v is Map)
    return UnmodifiableMapView<String, Object?>(
      v.map((k, v) => MapEntry(k as String, freeze(v))),
    );
  if (v is List) return UnmodifiableListView<Object?>(v.map(freeze).toList());
  return v;
}

Object? canonical(Object? v) => v is Map
    ? {
        for (final k in (v.keys.cast<String>().toList()..sort()))
          k: canonical(v[k]),
      }
    : v is List
    ? v.map(canonical).toList()
    : v;
String canonicalJson(Object? v) => jsonEncode(canonical(v));

class JsonValue {
  final Map<String, dynamic> data;
  JsonValue(Map<String, dynamic> value)
    : data = Map<String, dynamic>.unmodifiable(freeze(value) as Map);
  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  @override
  bool operator ==(Object o) =>
      o.runtimeType == runtimeType &&
      o is JsonValue &&
      const DeepCollectionEquality().equals(data, o.data);
  @override
  int get hashCode => const DeepCollectionEquality().hash(data);
}

class GridPos {
  final int x, y;
  const GridPos(this.x, this.y);
  factory GridPos.fromJson(Map p) => GridPos(p['x'] as int, p['y'] as int);
  Map<String, int> toJson() => {'x': x, 'y': y};
  int distance(GridPos o) => (x - o.x).abs() + (y - o.y).abs();
  @override
  bool operator ==(Object o) => o is GridPos && x == o.x && y == o.y;
  @override
  int get hashCode => Object.hash(x, y);
}

class WorldConfig extends JsonValue {
  WorldConfig({
    int seed = 1,
    int width = 64,
    int height = 64,
    int populationMax = 20,
  }) : super({
         'schemaVersion': 1,
         'rulesVersion': 1,
         'seed': seed,
         'width': width,
         'height': height,
         'populationMax': populationMax,
       }) {
    if (seed < 1 ||
        seed > 0xffffffff ||
        width < 1 ||
        width > 256 ||
        height < 1 ||
        height > 256 ||
        populationMax < 1 ||
        populationMax > 1000)
      throw ArgumentError('Invalid config');
  }
  WorldConfig.fromJson(super.value);
  int get width => data['width'];
  int get height => data['height'];
  int get seed => data['seed'];
  int get populationMax => data['populationMax'];
}

class AgentState extends JsonValue {
  AgentState({
    required String id,
    required String name,
    required GridPos position,
    int hunger = 60,
    int energy = 80,
    int inventoryFood = 0,
  }) : super({
         'id': id,
         'name': name,
         'position': position.toJson(),
         'hunger': hunger,
         'energy': energy,
         'inventoryFood': inventoryFood,
         'currentAction': null,
         'goal': 'explorer',
         'failureCount': 0,
         'nextDecisionTick': 0,
         'behaviorProfile': 'local_v1',
       });
  AgentState.fromJson(super.value);
  String get id => data['id'];
  String get name => data['name'];
  GridPos get position => GridPos.fromJson(data['position']);
  int get hunger => data['hunger'];
  int get energy => data['energy'];
  int get inventoryFood => data['inventoryFood'];
  String? get currentAction => data['currentAction'];
  String get goal => data['goal'];
  int get failureCount => data['failureCount'];
  int get nextDecisionTick => data['nextDecisionTick'];
}

class ResourceState extends JsonValue {
  ResourceState.fromJson(super.value);
  String get id => data['id'];
  GridPos get position => GridPos.fromJson(data['position']);
  int get food => data['food'];
  String? get reservationAgentId => data['reservationAgentId'];
}

class PendingAction extends JsonValue {
  PendingAction.fromJson(super.value);
}

class WorldEvent extends JsonValue {
  WorldEvent.fromJson(super.value);
  String get kind => data['kind'];
  String? get actorId => data['actorId'];
  int get tick => data['tick'];
  List<String> get observedBy => List<String>.unmodifiable(data['observedBy']);
}

class WorldState extends JsonValue {
  WorldState(super.value);
  String get worldId => data['worldId'];
  WorldConfig get config =>
      WorldConfig.fromJson(Map<String, dynamic>.from(data['config']));
  int get tick => data['tick'];
  int get revision => data['revision'];
  int get rngState => data['rngState'];
  int get schedulerCursor => data['schedulerCursor'];
  int get decisionSequence => data['decisionSequence'];
  List<AgentState> get agents => List.unmodifiable(
    (data['agents'] as List).map(
      (a) => AgentState.fromJson(Map<String, dynamic>.from(a)),
    ),
  );
  List<ResourceState> get resources => List.unmodifiable(
    (data['resources'] as List).map(
      (a) => ResourceState.fromJson(Map<String, dynamic>.from(a)),
    ),
  );
  List<GridPos> get blockedCells => List.unmodifiable(
    (data['blockedCells'] as List).map((p) => GridPos.fromJson(p)),
  );
  List<WorldEvent> get eventLog => List.unmodifiable(
    (data['eventLog'] as List).map(
      (a) => WorldEvent.fromJson(Map<String, dynamic>.from(a)),
    ),
  );
}

class WorldSnapshot {
  final WorldState state;
  const WorldSnapshot(this.state);
  @override
  bool operator ==(Object o) => o is WorldSnapshot && o.state == state;
  @override
  int get hashCode => state.hashCode;
}

enum ActionKind { move, gather, consume, rest }

enum ActionStatus { applied, rejected, pending }

class ActionProposal extends JsonValue {
  ActionProposal({
    required String commandId,
    required String worldId,
    required String actorId,
    required int expectedRevision,
    required int issuedTick,
    required int expiresTick,
    required ActionKind kind,
    Map<String, dynamic> arguments = const {},
  }) : super({
         'schemaVersion': 1,
         'commandId': commandId,
         'worldId': worldId,
         'actorId': actorId,
         'expectedRevision': expectedRevision,
         'issuedTick': issuedTick,
         'expiresTick': expiresTick,
         'kind': kind.name,
         'arguments': arguments,
       });
  ActionProposal._(super.value);
  static ActionProposal fromJson(Map<String, dynamic> v) {
    const keys = {
      'schemaVersion',
      'commandId',
      'worldId',
      'actorId',
      'expectedRevision',
      'issuedTick',
      'expiresTick',
      'kind',
      'arguments',
    };
    if (v.keys.toSet().difference(keys).isNotEmpty ||
        v.length != keys.length ||
        v['schemaVersion'] != 1 ||
        !ActionKind.values.any((k) => k.name == v['kind']))
      throw const FormatException('Invalid command');
    for (final k in ['commandId', 'worldId', 'actorId']) {
      if (v[k] is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(v[k]))
        throw const FormatException('Invalid ID');
    }
    for (final k in ['expectedRevision', 'issuedTick', 'expiresTick']) {
      if (v[k] is! int || v[k] < 0 || v[k] > 9007199254740991)
        throw const FormatException('Invalid integer');
    }
    if (v['arguments'] is! Map<String, dynamic>)
      throw const FormatException('Invalid arguments');
    final a = v['arguments'] as Map;
    final kind = v['kind'];
    if (kind == 'move' && (a.length != 2 || a['x'] is! int || a['y'] is! int) ||
        kind == 'gather' && (a.length != 1 || a['resourceId'] is! String) ||
        ['consume', 'rest'].contains(kind) && a.isNotEmpty)
      throw const FormatException('Invalid arguments');
    return ActionProposal._(v);
  }

  String get commandId => data['commandId'];
  String get actorId => data['actorId'];
  ActionKind get kind => ActionKind.values.byName(data['kind']);
  Map<String, dynamic> get arguments => Map.unmodifiable(data['arguments']);
}

class ActionResult {
  final String commandId, code;
  final ActionStatus status;
  final List<WorldEvent> events;
  const ActionResult(
    this.commandId,
    this.status,
    this.code, [
    this.events = const [],
  ]);
}

class WorldView {
  final WorldSnapshot snapshot;
  final String? selectedAgentId;
  final int requestedSpeed;
  final double effectiveSpeed;
  final String mode;
  const WorldView(
    this.snapshot, {
    this.selectedAgentId,
    this.requestedSpeed = 1,
    this.effectiveSpeed = 0,
    this.mode = 'rules',
  });
}
