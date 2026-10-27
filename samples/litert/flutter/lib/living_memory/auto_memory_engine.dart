import 'auto_memory_candidate.dart';
import 'memory_store.dart';

/// Sequential work, bounded per user action; no timer or background service.
class AutoMemoryEngine {
  AutoMemoryEngine({
    required this.store,
    required this.extract,
    required this.embed,
    required this.cancelled,
    this.extractorIdentity = extractorId,
  });
  final MemoryStore store;
  final Future<List<AutoMemoryCandidate>> Function(String) extract;
  final Future<List<double>> Function(String) embed;
  final bool Function() cancelled;
  bool _running = false;
  final String extractorIdentity;
  static const extractorId = 'Gemma 4 E2B/extractive-v1';

  Future<({int processed, int added})> process(
    String agentId,
    String documentId,
  ) async {
    if (_running) throw StateError('Extraction déjà en cours.');
    if (cancelled() || !store.autoMemoryEnabled(agentId)) {
      return (processed: 0, added: 0);
    }
    _running = true;
    var processed = 0;
    var added = 0;
    try {
      for (final passage in store.memoryPassages(agentId, documentId)) {
        if (cancelled() || !store.autoMemoryEnabled(agentId)) break;
        final candidates = await extract(passage.text);
        if (cancelled() || !store.autoMemoryEnabled(agentId)) break;
        if (candidates.length > 3) {
          throw const FormatException('Maximum 3 souvenirs par passage.');
        }
        // Validate the entire output before any embeddings or writes.
        for (final c in candidates) {
          c.validate(passage.text);
        }
        for (final c in candidates) {
          final vector = await embed(c.quote);
          if (cancelled() || !store.autoMemoryEnabled(agentId)) {
            return (processed: processed, added: added);
          }
          store.addMemory(
            agentId: agentId,
            documentId: documentId,
            ordinal: passage.ordinal,
            candidate: c,
            vector: vector,
            extractor: extractorIdentity,
          );
          added++;
        }
        store.completeMemoryPassage(
          agentId,
          documentId,
          passage.ordinal,
          extractorIdentity,
        );
        processed++;
      }
      return (processed: processed, added: added);
    } finally {
      _running = false;
    }
  }
}
