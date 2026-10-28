import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/config/knowledge_config.dart';
import 'package:litert_edge_demos/data/services/knowledge/embedder_service.dart';
import 'package:litert_edge_demos/domain/models/knowledge_query.dart';
import 'package:litert_edge_demos/living_memory/context_lifecycle_manager.dart';
import 'package:litert_edge_demos/living_memory/memory_screen.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';
import 'package:litert_edge_demos/utils/result.dart';

import '../fakes/fake_conversation_repository.dart';

class _Embedder implements EmbedderService {
  @override
  Future<Result<List<double>>> embedQuery(KnowledgeQuery query) async =>
      Result.ok([1, ...List.filled(kKbEmbeddingDimension - 1, 0.0)]);
  @override
  Future<Result<List<List<double>>>> embedDocuments(List<String> texts) async =>
      Result.ok([
        for (final _ in texts)
          [1, ...List.filled(kKbEmbeddingDimension - 1, 0.0)],
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final resetCase in ['none', 'immediate', 'later']) {
    testWidgets(
      'scoped chat and explicit save respect reset/compaction: $resetCase',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync('assistant-screen-');
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => dir.path,
        );
        final seed = MemoryStore.open(
          '${dir.path}/living-memory-v1.db',
          profile: kKbEmbeddingProfileId,
          dimension: kKbEmbeddingDimension,
        );
        seed.createAgent('personal', 'Ma mémoire');
        seed.createAgent('other', 'Zzz autre agent');
        final personal = ContextLifecycleManager(
          seed,
          const MemoryScope(agentId: 'personal'),
        );
        final personalSession = personal.startSession();
        personal.append(personalSession, 'user', 'SCOPE-ONLY-42');
        if (resetCase != 'none') {
          personal.resetActiveContext(personalSession);
          if (resetCase == 'later')
            personal.append(personalSession, 'user', 'NEW-ACTIVE-57');
          personal.compact(personalSession);
        }
        final other = ContextLifecycleManager(
          seed,
          const MemoryScope(agentId: 'other'),
        );
        other.append(other.startSession(), 'user', 'OTHER-SECRET-99');
        seed.close();
        final chat = FakeConversationRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: MemoryScreen(embedder: _Embedder(), conversation: chat),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Bonjour');
        await tester.ensureVisible(find.text('Discuter'));
        await tester.tap(find.text('Discuter'));
        for (var n = 0; n < 30 && chat.prompts.isEmpty; n++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(chat.prompts, hasLength(1));
        chat.emit('Bonjour Tivini.');
        final finish = chat.finish();
        await tester.pumpAndSettle();
        await finish;
        expect(find.text('Bonjour Tivini.'), findsWidgets);
        expect(
          chat.prompts.single,
          resetCase == 'none'
              ? contains('SCOPE-ONLY-42')
              : isNot(contains('SCOPE-ONLY-42')),
        );
        if (resetCase == 'later')
          expect(chat.prompts.single, contains('NEW-ACTIVE-57'));
        expect(chat.prompts.single, isNot(contains('OTHER-SECRET-99')));
        final store = MemoryStore.open(
          '${dir.path}/living-memory-v1.db',
          profile: kKbEmbeddingProfileId,
          dimension: kKbEmbeddingDimension,
        );
        expect(
          store
              .sessionMessages(
                const MemoryScope(agentId: 'personal').key,
                personalSession,
              )
              .any((m) => m.text == 'SCOPE-ONLY-42'),
          isTrue,
          reason: 'reset preserves the archive',
        );
        expect(
          store.documents('personal'),
          isEmpty,
          reason: 'no implicit durable source from AI output',
        );
        await tester.ensureVisible(find.text('Conserver la production'));
        await tester.tap(find.text('Conserver la production'));
        await tester.pumpAndSettle();
        expect(store.documents('personal'), hasLength(1));
        expect(store.documents('personal').single.kind, 'assistant-draft');
        expect(store.documents('other'), isEmpty);
        final agentSelector = find.byType(DropdownButtonFormField<String>);
        await tester.scrollUntilVisible(
          agentSelector,
          -400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(agentSelector);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Zzz autre agent').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Discuter'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Conserver la production'), findsNothing);
        await tester.enterText(find.byType(TextField), 'Salut');
        await tester.ensureVisible(find.text('Discuter'));
        await tester.tap(find.text('Discuter'));
        for (var n = 0; n < 30 && chat.prompts.length < 2; n++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(chat.prompts, hasLength(2));
        chat.emit('Réponse de l’autre agent.');
        final finishedOther = chat.finish();
        await tester.pumpAndSettle();
        await finishedOther;
        expect(chat.prompts.last, contains('OTHER-SECRET-99'));
        expect(chat.prompts.last, isNot(contains('SCOPE-ONLY-42')));
        expect(chat.prompts.last, isNot(contains('Bonjour Tivini.')));
        expect(store.documents('other'), isEmpty);
        store.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await chat.close();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        dir.deleteSync(recursive: true);
      },
    );
  }
}
