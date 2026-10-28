import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/domain/models/assistant_event.dart';
import 'package:litert_edge_demos/living_memory/assistant_session.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';
import 'package:litert_edge_demos/utils/result.dart';

import '../fakes/fake_conversation_repository.dart';

class _Chat extends FakeConversationRepository {
  List<AssistantEvent> events = [
    const AssistantTextDelta('Brouillon'),
    AssistantDone(FakeConversationRepository.metrics()),
  ];
  @override
  Stream<AssistantEvent> ask(
    String prompt, {
    Uint8List? image,
    Uint8List? audioWav,
    dynamic onStep,
    String? historyText,
    int? turn,
  }) async* {
    prompts.add(prompt);
    images.add(image);
    yield* Stream.fromIterable(events);
  }
}

void main() {
  const a = MemoryScope(agentId: 'a', projectId: 'projet');
  const b = MemoryScope(agentId: 'b');
  test(
    'each agent opens a fresh tool-free conversation and keeps provenance',
    () async {
      final chat = _Chat();
      final assistant = AssistantSession(chat);
      final first = await assistant.generate(a, 'Bonjour');
      final second = await assistant.generate(
        b,
        'Rédige un texte',
        draft: true,
      );
      expect(chat.openCalls, 2);
      expect(first.scopeKey, a.key);
      expect(second.scopeKey, b.key);
      expect(first.text, 'Brouillon');
      expect(first.kind, 'assistant-draft');
      expect(first.sourceLabel, contains('non vérifiée'));
      expect(
        chat.openedProfiles.every((p) => p.name.startsWith('living-assistant')),
        isTrue,
      );
      await chat.close();
    },
  );
  test(
    'image bytes reach inference and a stable digest labels derived text',
    () async {
      final chat = _Chat();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await AssistantSession(chat)
          .generate(a, 'Décris', image: bytes);
      expect(chat.images.single, same(bytes));
      expect(result.kind, 'image-description');
      expect(result.sourceLabel, contains('039058c6'));
      await chat.close();
    },
  );
  test(
    'stream without terminal, stopped, empty and failed replies are rejected',
    () async {
      for (final events in <List<AssistantEvent>>[
        [const AssistantTextDelta('partiel')],
        [
          const AssistantTextDelta('partiel'),
          AssistantDone(FakeConversationRepository.metrics(stopped: true)),
        ],
        [AssistantDone(FakeConversationRepository.metrics())],
        [AssistantFailed(Exception('native'))],
      ]) {
        final chat = _Chat()..events = events;
        await expectLater(
          AssistantSession(chat).generate(a, 'Bonjour'),
          throwsA(isA<Exception>()),
        );
        await chat.close();
      }
    },
  );
  test('cancellation after open prevents generation', () async {
    final chat = _Chat()..openGate = Completer<void>();
    var cancelled = false;
    final work = AssistantSession(chat)
        .generate(a, 'Bonjour', cancelled: () => cancelled);
    final assertion = expectLater(work, throwsA(isA<Exception>()));
    cancelled = true;
    chat.openGate!.complete();
    await assertion;
    expect(chat.prompts, isEmpty);
    await chat.close();
  });
  test('context refusal and invalid scope fail before ask', () async {
    final chat = _Chat()..promptFit = (_) => const Result.ok(null);
    await expectLater(
      AssistantSession(chat).generate(a, 'Bonjour'),
      throwsA(isA<Exception>()),
    );
    expect(chat.prompts, isEmpty);
    await expectLater(
      AssistantSession(chat)
          .generate(const MemoryScope(agentId: ''), 'Bonjour'),
      throwsArgumentError,
    );
    await chat.close();
  });
}
