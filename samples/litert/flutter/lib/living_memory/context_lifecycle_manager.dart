import 'dart:convert';

import 'memory_store.dart';
import 'module_contracts.dart';

/// Extractive checkpoints are navigation aids, never verified memories.
/// The byte upper bound is conservative, not a tokenizer count.
class ContextLifecycleManager {
  ContextLifecycleManager(this.store, this.scope, {this.tokenBudget = 4096}) {
    if (tokenBudget < 256 || tokenBudget > 65536) {
      throw ArgumentError('Budget invalide');
    }
    scope.key;
  }
  final MemoryStore store;
  final MemoryScope scope;
  final int tokenBudget;
  String startSession() => store.createSession(scope.key, scope.agentId);
  List<({String id, String updatedAt})> sessions() =>
      store.contextSessions(scope.key);
  List<SessionMessage> messages(String id) =>
      store.sessionMessages(scope.key, id);
  List<ContextCheckpoint> checkpoints(String id) =>
      store.sessionCheckpoints(scope.key, id);
  void append(String id, String role, String text, {bool decision = false}) =>
      store.appendSessionMessage(scope.key, id, role, text, decision: decision);
  void markDecision(String id, int ordinal, {required bool decision}) =>
      store.markSessionDecision(scope.key, id, ordinal, decision: decision);
  int activeTokenEstimate(String id) {
    final checkpoint = checkpoints(id).lastOrNull;
    var total = checkpoint == null
        ? 0
        : utf8.encode(checkpoint.summary).length + 16;
    for (final m in messages(id)) {
      if (m.ordinal > (checkpoint?.throughOrdinal ?? 0)) {
        total += utf8.encode(m.text).length + 16;
      }
    }
    return total;
  }

  bool needsCompaction(String id) =>
      activeTokenEstimate(id) >= tokenBudget * 0.75;
  ContextCheckpoint compact(String id) {
    final original = messages(id);
    final lines = <String>[];
    var bytes = 0;
    // Prefer explicit user decisions, then recent user messages. Full messages
    // that do not fit remain accessible in the archive.
    final ordered = [
      ...original.where((m) => m.decision),
      ...original.reversed.where((m) => m.role == 'user' && !m.decision),
    ];
    for (final m in ordered) {
      final line =
          '[message ${m.ordinal}${m.decision ? ', décision utilisateur' : ', utilisateur'}] ${m.text}';
      final size = utf8.encode(line).length + 1;
      if (bytes + size > (tokenBudget ~/ 2).clamp(0, 20000)) continue;
      lines.add(line);
      bytes += size;
    }
    return store.writeCheckpoint(
      scope.key,
      id,
      original.lastOrNull?.ordinal ?? 0,
      lines.join('\n'),
      'compact',
    );
  }

  ContextCheckpoint resetActiveContext(String id) {
    final original = messages(id);
    return store.writeCheckpoint(
      scope.key,
      id,
      original.lastOrNull?.ordinal ?? 0,
      '',
      'reset',
    );
  }
}
