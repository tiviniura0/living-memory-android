import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/config/model_catalog.dart';
import 'package:litert_edge_demos/data/repositories/chat_model_repository.dart';
import 'package:litert_edge_demos/data/services/llm/llm_service.dart';
import 'package:litert_edge_demos/domain/use_cases/chat_model_switcher.dart';
import 'package:litert_edge_demos/living_memory/multimodel/litert_memory_runtime.dart';
import 'package:litert_edge_demos/living_memory/multimodel/model_registry.dart';
import 'package:litert_edge_demos/living_memory/multimodel/multi_model_engine.dart';
import 'package:litert_edge_demos/utils/result.dart';

import '../../fakes/fake_conversation_repository.dart';
import '../../fakes/fake_inference_model.dart';

class _FailingClose extends FakeInferenceModel {
  @override
  Future<void> close() async => throw StateError('native close failed');
}

class _Models implements ChatModelRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'real lifecycle adapter refuses fallback after model close fails',
    () async {
      final dir = Directory.systemTemp.createTempSync('native-release-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final chat = FakeConversationRepository();
      addTearDown(chat.close);
      var loads = 0;
      final llm = LlmService(
        loadModel: (_) async {
          loads++;
          return _FailingClose();
        },
      );
      await llm.load(kDefineChatModel);
      final switcher = ChatModelSwitcher(
        conversation: chat,
        reloadChatModel: () async => const Result.ok(null),
        unloadChatModel: llm.unload,
        refuseChatModelLoads: (_) {},
      );
      final runtime = LiteRtMemoryRuntime(
        ModelRegistry(dir),
        _Models(),
        switcher,
      );
      final engine = MultiModelEngine(runtime, available: () => {'e2b', 'e4b'});
      await expectLater(
        engine.run(
          const ModelTask.question('Compare'),
          (_) async => 'unreachable',
        ),
        throwsA(isA<ModelReleaseFailure>()),
      );
      expect(engine.fallbackReason, isNull);
      expect(loads, 1);
      expect(switcher.busy.value, isFalse);
    },
  );
}
