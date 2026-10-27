import 'world_types.dart';

// Typed boundary values only: these are NOT an operational memory adapter.
class PerceivedEvent extends JsonValue {
  PerceivedEvent(super.value);
}

class MemoryAck extends JsonValue {
  MemoryAck(super.value);
}

class RecallQuery extends JsonValue {
  RecallQuery(super.value);
}

class MemoryReference extends JsonValue {
  MemoryReference(super.value);
}

class ScopedMemoryId {
  final String worldId, agentId, memoryId;
  const ScopedMemoryId(this.worldId, this.agentId, this.memoryId);
}

class MemoryHealth {
  final String status;
  final String? reason;
  const MemoryHealth(this.status, {this.reason});
}

abstract interface class MemoryPort {
  Future<MemoryAck> ingest(PerceivedEvent event);
  Future<List<MemoryReference>> recall(RecallQuery query);
  Future<void> delete(ScopedMemoryId id);
  Future<MemoryHealth> health();
}
