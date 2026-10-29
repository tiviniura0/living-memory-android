import 'dart:convert';

/// Reserved persistent authorizations. Restores discard these records while
/// preserving sources and receipts; trusted hosts must obtain fresh approval.
const permissionRecordNamespacePrefix = 'permission.';

/// Namespace, not authentication. The Android application sandbox remains the
/// security boundary until an authenticated external API is implemented.
class MemoryScope {
  const MemoryScope({
    required this.agentId,
    this.userId = 'local',
    this.projectId = '',
    this.worldId = '',
  });
  final String userId;
  final String agentId;
  final String projectId;
  final String worldId;
  String get key {
    for (final value in [userId, agentId, projectId, worldId]) {
      if (value.length > 100 || value.contains('\u0000')) {
        throw ArgumentError('Portée invalide');
      }
    }
    if (userId.isEmpty || agentId.isEmpty) throw ArgumentError('Portée vide');
    return jsonEncode([userId, agentId, projectId, worldId]);
  }
}

/// Future ports: no implementations, external server or third-party code loader.
abstract interface class ModelRuntime {
  String get modelId;
  Future<T> withExclusiveModel<T>(Future<T> Function() operation);
  Future<void> release();
}

class AgentMission {
  const AgentMission(this.id, this.scope, this.instruction);
  final String id;
  final MemoryScope scope;
  final String instruction;
}

abstract interface class AgentRuntime {
  Future<void> resume(
    AgentMission mission, {
    required bool Function() cancelled,
  });
}

class ToolInvocation {
  const ToolInvocation(this.id, this.toolId, this.scope, this.arguments);
  final String id;
  final String toolId;
  final MemoryScope scope;
  final Map<String, Object?> arguments;
}

/// Only an approved runtime adapter may produce this envelope. Generated text
/// is never parsed into ToolResult by the memory extractor.
class ToolResult {
  const ToolResult({
    required this.invocationId,
    required this.adapterId,
    required this.finishedAt,
    required this.succeeded,
    required this.output,
  });
  final String invocationId;
  final String adapterId;
  final DateTime finishedAt;
  final bool succeeded;
  final Object? output;
}

abstract interface class ToolRegistry {
  Set<String> get approvedToolIds;
  Future<ToolResult> invoke(ToolInvocation invocation, PermissionGrant grant);
}

class PermissionGrant {
  const PermissionGrant(this.invocationId, this.scopeKey, this.expiresAt);
  final String invocationId;
  final String scopeKey;
  final DateTime expiresAt;
}

abstract interface class SecurityManager {
  Future<PermissionGrant?> requestPermission(ToolInvocation invocation);
  bool authorize(ToolInvocation invocation, PermissionGrant grant);
}

abstract interface class SkillsManager {
  Set<String> get approvedSkillIds;
  Future<String> loadApprovedInstructions(String skillId, MemoryScope scope);
}

abstract interface class Scheduler {
  Future<void> persist(AgentMission mission, DateTime earliestRun);
  Future<void> cancel(String missionId, MemoryScope scope);
}

abstract interface class ApplicationApi {
  Future<String> submit(AgentMission mission, String credential);
}
