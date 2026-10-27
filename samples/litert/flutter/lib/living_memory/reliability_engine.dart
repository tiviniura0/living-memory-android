import 'memory_store.dart';

class AnswerValidation {
  const AnswerValidation(this.accepted,this.text);
  final bool accepted;
  final String text;
}
class ReliabilityEngine {
  ReliabilityEngine(this.store);
  final MemoryStore store;
  static const abstention = 'Sources ou citations insuffisantes. Consulte les passages ; aucune réponse fiable ne peut être retenue.';

  /// Reciprocal rank fusion: ordering signals, never truth probabilities.
  List<MemoryHit> retrieve(String agentId, String question, List<double> vector,
    {double minSimilarity = 0.65, String projectId = '', String worldId = ''}) {
    final lists = [
      store.searchMemories(agentId,vector,minSimilarity: minSimilarity,projectId: projectId,worldId: worldId),
      store.search(agentId,vector,minSimilarity: minSimilarity,projectId: projectId,worldId: worldId),
      store.searchText(agentId,question,projectId: projectId,worldId: worldId),
    ];
    final hits = <String, MemoryHit>{};
    final scores = <String,double>{};
    for (final list in lists) {
      for (var i = 0; i < list.length; i++) {
        final hit = list[i];
        // Corrected memories and original passages remain distinguishable.
        final key = '${hit.documentId}/${hit.ordinal}/${hit.name}';
        hits[key] = hit;
        scores[key] = (scores[key] ?? 0) + 1 / (60 + i + 1);
      }
    }
    final keys = hits.keys.toList()..sort((a,b) {
      final rank = scores[b]!.compareTo(scores[a]!);
      return rank == 0 ? a.compareTo(b) : rank;
    });
    return [for (final key in keys.take(6)) hits[key]!];
  }

  /// Structural check only: does not prove entailment of each sentence.
  AnswerValidation validateAnswer(String answer,List<MemoryHit> evidence) {
    final citations = RegExp(r'\[(\d+)\]').allMatches(answer).toList();
    if (answer.trim().isEmpty || evidence.isEmpty || citations.isEmpty ||
      citations.any((m) { final n = int.tryParse(m.group(1)!); return n == null || n < 1 || n > evidence.length; })) {
      return const AnswerValidation(false,abstention);
    }
    return AnswerValidation(true,answer);
  }
}
