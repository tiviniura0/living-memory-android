/// Adapter boundary: implementations own the native model and the process lock.
/// No cloud, tools or model download belongs to this interface.
abstract interface class LocalModelRuntime {
  Future<T> exclusive<T>(Future<T> Function() operation);
  Future<void> unload();
  Future<void> load(String modelId);
}

enum ModelMode { auto, e2b, e4b }

class ModelTask {
  const ModelTask.extraction() : extraction = true, question = '', sourceCount = 0;
  const ModelTask.question(this.question, {this.sourceCount = 0}) : extraction = false;
  final bool extraction;
  final String question;
  final int sourceCount;

  // Explicit, deterministic heuristic; not an estimate of reasoning quality.
  bool get complex => !extraction && (sourceCount >= 4 || question.length > 500 ||
      RegExp(r'compar|synth[èe]s|contrad|analyse|expliqu|raisonn', caseSensitive: false).hasMatch(question));
}

class ModelReleaseFailure implements Exception {
  const ModelReleaseFailure();
  @override
  String toString() => 'Libération native refusée. Aucun autre modèle ne sera chargé.';
}

class ModelCancelled implements Exception {
  const ModelCancelled();
  @override
  String toString() => 'Opération annulée.';
}

/// One generative model at a time; exclusive lock spans the entire operation.
/// The embedder has its own existing lifecycle. A process kill cannot be caught.
class MultiModelEngine {
  MultiModelEngine(this.runtime, {required this.available});
  final LocalModelRuntime runtime;
  final Set<String> Function() available;
  ModelMode mode = ModelMode.auto;
  String _status = 'Déchargé';
  String get status => _status;
  void Function()? onChanged;
  set status(String value) { _status = value; onChanged?.call(); }
  String? lastUsed;
  String? fallbackReason;

  String choose(ModelTask task) {
    final ids = available();
    if (mode != ModelMode.auto) {
      if (!ids.contains(mode.name)) throw StateError('Modèle ${mode.name} non enregistré.');
      return mode.name;
    }
    if (task.complex && ids.contains('e4b')) return 'e4b';
    if (ids.contains('e2b')) return 'e2b';
    if (ids.contains('e4b')) return 'e4b';
    throw StateError('Aucun modèle enregistré.');
  }

  Future<T> run<T>(ModelTask task, Future<T> Function(String id) operation,
      {bool Function()? cancelled}) => runtime.exclusive(() async {
    void check() { if (cancelled?.call() ?? false) throw const ModelCancelled(); }
    check();
    fallbackReason = null;
    final preferred = choose(task);
    Future<T> attempt(String id) async {
      check();
      status = 'Déchargement avant $id';
      // Outside try/finally: if release fails, do not touch the native engine.
      await runtime.unload();
      try {
        check();
        status = 'Chargement $id';
        await runtime.load(id);
        check();
        status = 'Inférence $id';
        final result = await operation(id);
        check();
        lastUsed = id;
        return result;
      } finally {
        status = 'Déchargement $id';
        await runtime.unload();
        status = 'Déchargé';
      }
    }
    try {
      try {
        return await attempt(preferred);
      } on ModelReleaseFailure { rethrow;
      } on ModelCancelled { rethrow;
      } catch (error) {
        check();
        if (preferred != 'e4b' || !available().contains('e2b')) rethrow;
        fallbackReason = error.toString();
        return await attempt('e2b');
      }
    } catch (error) {
      status = 'Échec : $error';
      rethrow;
    }
  });
}
