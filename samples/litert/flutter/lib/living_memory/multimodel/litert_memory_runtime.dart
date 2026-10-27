import '../../data/repositories/chat_model_repository.dart';
import '../../domain/models/chat_model.dart';
import '../../domain/use_cases/chat_model_switcher.dart';
import '../../utils/result.dart';
import '../../data/services/model_store/models_folder.dart' show inspectLitertlm;
import 'model_registry.dart';
import 'multi_model_engine.dart';

T _value<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Error(:final error) => throw error,
};

/// Real adapter to the existing LiteRT-LM model lifecycle. No mock inference.
class LiteRtMemoryRuntime implements LocalModelRuntime {
  LiteRtMemoryRuntime(this.registry, this.models, this.switcher);
  final ModelRegistry registry;
  final ChatModelRepository models;
  final ChatModelSwitcher switcher;
  ChatModelOps? _ops;

  @override
  Future<T> exclusive<T>(Future<T> Function() operation) => switcher.exclusive((ops) async {
    _ops = ops;
    try { return await operation(); } finally { _ops = null; }
  });

  @override
  Future<void> unload() async {
    if (await _ops!.unload() case Error()) throw const ModelReleaseFailure();
  }

  @override
  Future<void> load(String id) async {
    final saved = registry.models[id];
    if (saved == null || !await registry.verify(id)) {
      throw StateError('$id : fichier absent ou empreinte incorrecte.');
    }
    final path = (saved.source as LocalModelSource).path;
    final bundle = _value(await inspectLitertlm(path));
    if (models.cannotRunHere(bundle.info) case final why?) throw StateError(why);
    final plan = CustomChatPlan(path: path, model: saved, bundle: bundle);
    final loaded = await models.withRuntimePlan(plan, _ops!.reload);
    if (loaded case Error(error: ReplyStillStoppingException())) {
      throw const ModelReleaseFailure();
    }
    _value(loaded);
  }
}
