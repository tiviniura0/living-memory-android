import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/config/knowledge_config.dart';
import 'package:litert_edge_demos/data/services/knowledge/embedder_service.dart';
import 'package:litert_edge_demos/domain/models/knowledge_query.dart';
import 'package:litert_edge_demos/living_memory/memory_screen.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/utils/result.dart';

import '../fakes/fake_conversation_repository.dart';

class _Embedder implements EmbedderService {
  @override
  Future<Result<List<double>>> embedQuery(KnowledgeQuery query) async =>
      Result.ok([1, ...List.filled(kKbEmbeddingDimension - 1, 0.0)]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat extends FakeConversationRepository {
  Completer<void>? fitGate;
  @override
  Future<Result<int?>> firstFittingPrompt(
    List<String> prompts, {
    Uint8List? image,
    Uint8List? audioWav,
  }) async {
    await fitGate?.future;
    return super.firstFittingPrompt(prompts, image: image, audioWav: audioWav);
  }
}

void main() {
  for (final stage in ['open', 'fit']) {
    testWidgets('stop during $stage never starts subsequent generation', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('cancel-screen-');
      final seed = MemoryStore.open(
        '${dir.path}/living-memory-v1.db',
        profile: kKbEmbeddingProfileId,
        dimension: kKbEmbeddingDimension,
      );
      seed.createAgent('personal', 'Ma mémoire');
      seed.addDocument(
        agentId: 'personal',
        name: 'Note',
        digest: 'x',
        chunks: [const MemoryChunk(page: 1, ordinal: 1, text: 'Original')],
        vectors: [
          [1, ...List.filled(kKbEmbeddingDimension - 1, 0.0)],
        ],
      );
      seed.close();
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => dir.path,
      );
      final chat = _Chat();
      final gate = Completer<void>();
      if (stage == 'open') {
        chat.openGate = gate;
      } else {
        chat.fitGate = gate;
      }
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryScreen(embedder: _Embedder(), conversation: chat),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Question');
      await tester.ensureVisible(find.text('Répondre avec Gemma'));
      await tester.tap(find.text('Répondre avec Gemma'));
      await tester.pump();
      await tester.ensureVisible(find.text('Arrêter'));
      await tester.tap(find.text('Arrêter'));
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(chat.prompts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await chat.close();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      dir.deleteSync(recursive: true);
    });
  }
}
