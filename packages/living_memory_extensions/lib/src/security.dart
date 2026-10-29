import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class ExtensionDenied implements Exception {
  const ExtensionDenied();
  @override
  String toString() => 'Extension request denied';
}

Object? _freeze(Object? value) {
  if (value == null || value is String || value is bool || value is int)
    return value;
  if (value is double && value.isFinite) return value;
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return Map<String, Object?>.unmodifiable({
      for (final key in keys) key: _freeze(value[key]),
    });
  }
  throw const FormatException('Only finite JSON values supported');
}

Map<String, Object?> frozenJson(Map<String, Object?> value) =>
    _freeze(value)! as Map<String, Object?>;
String fingerprintJson(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_freeze(value)))).toString();
void _id(String value) {
  if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_./:-]{0,127}$').hasMatch(value))
    throw const FormatException('Invalid identifier');
}

final class ExtensionScope {
  ExtensionScope({
    this.userId = 'local',
    required this.agentId,
    required this.projectId,
    required this.worldId,
  }) {
    if (userId != 'local') throw const ExtensionDenied();
    _id(agentId);
    for (final value in [projectId, worldId]) {
      if (value.length > 100 || value.contains('\u0000')) {
        throw const FormatException('Invalid namespace');
      }
    }
  }
  final String userId, agentId, projectId, worldId;
  Map<String, Object?> toJson() => {
    'userId': userId,
    'agentId': agentId,
    'projectId': projectId,
    'worldId': worldId,
  };
  String get key => jsonEncode(frozenJson(toJson()));
}

final class ExtensionRequest {
  ExtensionRequest({
    required this.scope,
    required this.tool,
    required Map<String, Object?> arguments,
    required this.pluginHash,
    this.version = 1,
  }) : arguments = frozenJson(arguments) {
    if (version != 1) throw const ExtensionDenied();
    _id(tool);
    if (utf8.encode(jsonEncode(this.arguments)).length > 65536)
      throw const FormatException('Arguments too large');
  }
  final ExtensionScope scope;
  final String tool, pluginHash;
  final Map<String, Object?> arguments;
  final int version;
  String get fingerprint => fingerprintJson({
    'version': version,
    'scope': scope.toJson(),
    'tool': tool,
    'arguments': arguments,
    'pluginHash': pluginHash,
  });
}

/// Construct only in the trusted host after explicit approval of this snapshot.
final class ApprovedPlugin {
  ApprovedPlugin._(this.id, this.tools, this.fingerprint);
  factory ApprovedPlugin.fromManifest(Map<String, Object?> manifest) {
    if (utf8.encode(jsonEncode(manifest)).length > 65536 ||
        manifest.keys.toSet().difference({
          'version',
          'id',
          'revision',
          'tools',
        }).isNotEmpty ||
        manifest['version'] != 1 ||
        manifest['id'] is! String ||
        manifest['revision'] is! String ||
        manifest['tools'] is! List) {
      throw const FormatException('Invalid declarative plugin');
    }
    final id = manifest['id']! as String;
    _id(id);
    _id(manifest['revision']! as String);
    final tools = <String>{};
    for (final tool in manifest['tools']! as List) {
      if (tool is! String) throw const FormatException('Invalid tool');
      _id(tool);
      if (!tools.add(tool)) throw const FormatException('Duplicate tool');
    }
    return ApprovedPlugin._(
      id,
      Set.unmodifiable(tools),
      fingerprintJson(manifest),
    );
  }
  final String id, fingerprint;
  final Set<String> tools;
}

/// Existing SkillCatalog parser supplies this text; this class never parses files.
final class ApprovedInstructions {
  ApprovedInstructions({
    required this.id,
    required this.instructions,
    required this.catalogFingerprint,
  }) {
    _id(id);
    if (utf8.encode(instructions).length > 4096)
      throw const FormatException('Instructions too large');
  }
  final String id, instructions, catalogFingerprint;
  String get fingerprint => fingerprintJson({
    'id': id,
    'instructions': instructions,
    'catalog': catalogFingerprint,
  });
  bool matchesApproval(String approvedFingerprint) =>
      approvedFingerprint == fingerprint;
}

final class _Grant {
  _Grant(this.request, this.expiresAt);
  final String request;
  final DateTime expiresAt;
}

/// Process-local capabilities are never serialized or restored.
final class SecurityManager {
  SecurityManager({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final _grants = <String, _Grant>{};
  final _random = Random.secure();
  String approve(ExtensionRequest request, {required DateTime expiresAt}) {
    if (!expiresAt.isAfter(_clock())) throw const ExtensionDenied();
    _grants.removeWhere((_, grant) => !grant.expiresAt.isAfter(_clock()));
    if (_grants.length >= 4096) throw const ExtensionDenied();
    final token = base64Url.encode(
      List.generate(32, (_) => _random.nextInt(256)),
    );
    _grants[token] = _Grant(request.fingerprint, expiresAt);
    return token;
  }

  void revoke(String token) => _grants.remove(token);
  void consume(ExtensionRequest request, String token) {
    final grant = _grants.remove(token);
    if (grant == null ||
        !grant.expiresAt.isAfter(_clock()) ||
        grant.request != request.fingerprint)
      throw const ExtensionDenied();
  }
}

typedef ToolAdapter = Future<Map<String, Object?>> Function(
  ExtensionRequest request,
);

final class _Tool {
  _Tool(this.plugin, this.invoke);
  final ApprovedPlugin plugin;
  final ToolAdapter invoke;
}

final class ToolRegistry {
  ToolRegistry({
    required this.security,
    this.timeout = const Duration(seconds: 30),
  }) {
    if (timeout <= Duration.zero || timeout > const Duration(minutes: 2))
      throw ArgumentError('Invalid tool timeout');
  }
  final SecurityManager security;
  final Duration timeout;
  final _tools = <String, _Tool>{};
  bool _inFlight = false;
  void register({
    required ApprovedPlugin plugin,
    required String tool,
    required ToolAdapter invoke,
  }) {
    if (!plugin.tools.contains(tool)) throw const ExtensionDenied();
    _tools[tool] = _Tool(plugin, invoke);
  }

  Future<Map<String, Object?>> invoke(
    ExtensionRequest request,
    String grant,
  ) async {
    if (_inFlight) throw const ExtensionDenied();
    final tool = _tools[request.tool];
    if (tool == null || tool.plugin.fingerprint != request.pluginHash)
      throw const ExtensionDenied();
    security.consume(request, grant);
    // A timeout bounds the caller's wait, not the adapter's lifetime. Keep the
    // singleton host dispatcher occupied until the original effect settles.
    _inFlight = true;
    final effect = Future<Map<String, Object?>>.sync(() => tool.invoke(request))
        .whenComplete(() {
          _inFlight = false;
        });
    final result = frozenJson(await effect.timeout(timeout));
    if (utf8.encode(jsonEncode(result)).length > 1048576)
      throw const FormatException('Tool result too large');
    return result;
  }
}
