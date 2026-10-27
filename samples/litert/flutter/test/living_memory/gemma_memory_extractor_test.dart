import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/domain/models/chat_capabilities.dart';
import 'package:litert_edge_demos/living_memory/gemma_memory_extractor.dart';
import 'package:litert_edge_demos/utils/result.dart';

import '../fakes/fake_conversation_repository.dart';

void main() {
  late FakeConversationRepository chat;
  late GemmaMemoryExtractor extractor;
  setUp(() {
    chat = FakeConversationRepository()
      ..capabilities = const ChatCapabilities(
        modelName: 'Gemma 4 E2B',
        images: false,
        tools: false,
      );
    extractor = GemmaMemoryExtractor(chat, cancelled: () => false);
  });
  tearDown(() async {
    await chat.close();
  });
  Future<void> started() async {
    for (var i = 0; i < 20 && !chat.isGenerating.value; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(chat.isGenerating.value, isTrue);
  }

  test('fresh tool-free local chat returns only grounded candidates', () async {
    final result = extractor.extract('Note durable.');
    await started();
    chat.emit(
      '[{"quote":"Note durable.","kind":"observation","subject":"","relation":"","value":"","uncertain":true}]',
    );
    await chat.finish();
    expect((await result).single.quote, 'Note durable.');
    expect(chat.hasSkills, isFalse);
    expect(chat.profile!.name, 'auto-memory-extractive-v1');
    expect(chat.prompts.single, contains('Note durable.'));
  });
  test('imported Gemma file default display name can extract', () async {
    chat.capabilities = const ChatCapabilities(
      modelName: 'gemma-4-E2B-it',
      images: false,
      tools: false,
    );
    final result = extractor.extract('Note durable.');
    await started();
    chat.emit('[]');
    await chat.finish();
    expect(await result, isEmpty);
    expect(chat.prompts, hasLength(1));
  });
  test('stopped model output is rejected even when valid JSON', () async {
    final result = extractor.extract('Note durable.');
    final check = expectLater(result, throwsStateError);
    await started();
    chat.emit('[]');
    await chat.finish(stopped: true);
    await check;
  });
  test('invented quote is never accepted', () async {
    final result = extractor.extract('Note durable.');
    final check = expectLater(result, throwsFormatException);
    await started();
    chat.emit(
      '[{"quote":"inventé","kind":"observation","subject":"","relation":"","value":"","uncertain":false}]',
    );
    await chat.finish();
    await check;
  });
  test(
    'wrong model or insufficient context makes no generation call',
    () async {
      chat.capabilities = const ChatCapabilities(
        modelName: 'Other',
        images: false,
        tools: false,
      );
      await expectLater(extractor.extract('Note'), throwsStateError);
      expect(chat.prompts, isEmpty);
      chat.capabilities = const ChatCapabilities(
        modelName: 'Gemma 4 E2B',
        images: false,
        tools: false,
      );
      chat.promptFit = (_) => const Result.ok(null);
      await expectLater(extractor.extract('Note'), throwsStateError);
      expect(chat.prompts, isEmpty);
    },
  );
}
