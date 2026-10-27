import '../utils/citations.dart';
import 'memory_store.dart';
import 'module_contracts.dart';

class AnswerValidation {
  const AnswerValidation({required this.accepted, required this.text});
  final bool accepted;
  final String text;
}

class ReliabilityEngine {
  ReliabilityEngine(this.store);
  final MemoryStore store;
  static const abstention =
      'Sources ou citations insuffisantes. Consulte les passages ; aucune réponse fiable ne peut être retenue.';

  /// Reciprocal rank fusion: ordering signals, never truth probabilities.
  List<MemoryHit> retrieve(
    String agentId,
    String question,
    List<double> vector, {
    double minSimilarity = 0.65,
    String projectId = '',
    String worldId = '',
  }) {
    final lists = [
      store.searchMemories(
        agentId,
        vector,
        minSimilarity: minSimilarity,
        projectId: projectId,
        worldId: worldId,
      ),
      store.search(
        agentId,
        vector,
        minSimilarity: minSimilarity,
        projectId: projectId,
        worldId: worldId,
      ),
      store.searchText(
        agentId,
        question,
        projectId: projectId,
        worldId: worldId,
      ),
      store.searchDecisions(
        MemoryScope(
          agentId: agentId,
          projectId: projectId,
          worldId: worldId,
        ).key,
        agentId,
        question,
      ),
    ];
    final hits = <String, MemoryHit>{};
    final scores = <String, double>{};
    for (final list in lists) {
      for (var i = 0; i < list.length; i++) {
        final hit = list[i];
        // Corrected memories and original passages remain distinguishable.
        final key = '${hit.documentId}/${hit.ordinal}/${hit.name}';
        hits.putIfAbsent(key, () => hit);
        scores[key] = (scores[key] ?? 0) + 1 / (60 + i + 1);
      }
    }
    final keys = hits.keys.toList()
      ..sort((a, b) {
        final rank = scores[b]!.compareTo(scores[a]!);
        return rank == 0 ? a.compareTo(b) : rank;
      });
    return [for (final key in keys.take(6)) hits[key]!];
  }

  /// Structural check only: does not prove entailment of each sentence.
  AnswerValidation validateAnswer(String answer, List<MemoryHit> evidence) {
    final citations = findCitations(answer, count: evidence.length).toList();
    final numericMarkers = RegExp(r'\[(\d+(?:\s*[,–-]\s*\d+)*)\]').allMatches(answer).toList();
    if (answer.trim().isEmpty ||
        evidence.isEmpty ||
        citations.isEmpty ||
        numericMarkers.any((m) => !citations.any((c) => c.start == m.start && c.end == m.end))) {
      return const AnswerValidation(accepted: false, text: abstention);
    }
    return AnswerValidation(accepted: true, text: answer);
  }
}
