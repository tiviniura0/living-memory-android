import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/extensions_panel.dart';
import 'package:litert_edge_demos/living_memory/world_memory_panel.dart';
import 'package:living_memory_core/living_memory_core.dart';

// Real checkpoint File I/O needs the real event loop, outside fake frame time.
Future<void> settleStorage(WidgetTester tester) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (tester.any(find.byType(LinearProgressIndicator))) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Storage did not settle');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'world uses L1 simulation and explicit private then shared memory',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('world-panel-');
      final store = MemoryStore.open(
        '${dir.path}/memory.db',
        profile: 'test',
        dimension: 2,
      );
      addTearDown(() {
        store.close();
        dir.deleteSync(recursive: true);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorldMemoryPanel(
            store: store,
            embed: (_) async => [1, 0],
            directory: dir,
          ),
        ),
      );
      await settleStorage(tester);
      expect(find.textContaining('Règles locales'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('world-note')),
        'SECRET_LAGON42',
      );
      await tester.ensureVisible(find.text('Mémoriser pour A'));
      await tester.tap(find.text('Mémoriser pour A'));
      await settleStorage(tester);
      expect(
        store.extensionDatabase
            .select(
              "SELECT count(*) AS n FROM lm_v14_records WHERE namespace='world.event'",
            )
            .single['n'],
        1,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      await tester.scrollUntilVisible(find.textContaining('Souvenir privé enregistré'), 120, scrollable: find.byType(Scrollable).first);
      expect(
        find.textContaining('Souvenir privé enregistré'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      await tester.ensureVisible(find.text('Partager avec B'));
      await tester.tap(find.text('Partager avec B'));
      await settleStorage(tester);
      await tester.scrollUntilVisible(find.textContaining('Publication explicite'), 120, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Publication explicite'), findsOneWidget);
      await tester.ensureVisible(find.text('Consulter B'));
      await tester.tap(find.text('Consulter B'));
      await settleStorage(tester);
      await tester.scrollUntilVisible(find.textContaining('shared_declaration'), 120, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('shared_declaration'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'approved Skill and one gesture gate a real scoped tool and queued mission',
    (tester) async {
      final store = MemoryStore.open(':memory:', profile: 'test', dimension: 2);
      addTearDown(store.close);
      store.createAgent('a', 'A');
      store.addDocument(
        agentId: 'a',
        name: 'note',
        digest: 'd',
        chunks: [
          const MemoryChunk(
            page: 1,
            ordinal: 1,
            text: 'Le code zirconium est ZR42.',
          ),
        ],
        vectors: [
          [1, 0],
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ExtensionsPanel(
            store: store,
            scope: const MemoryScope(agentId: 'a'),
            loadSkill: () async => '---\nname: memory-scope\ndescription: Read permitted memory.\n---\nRead only approved scoped sources.',
            loadPlugin: () async => {
              'version': 1,
              'id': 'local-memory',
              'revision': '1',
              'tools': ['memory.read'],
            },
          ),
        ),
      );
      await settleStorage(tester);
      await tester.enterText(
        find.byKey(const Key('extension-query')),
        'zirconium',
      );
      await tester.tap(find.text('Approuver ce Skill'));
      await settleStorage(tester);
      await tester.tap(find.text('Autoriser cette lecture'));
      await settleStorage(tester);
      expect(find.textContaining('ZR42'), findsOneWidget);
      await tester.ensureVisible(find.text('Planifier cette lecture'));
      await tester.tap(find.text('Planifier cette lecture'));
      await settleStorage(tester);
      expect(find.textContaining('queued'), findsOneWidget);
      final encodedScope =
          store.extensionDatabase
                  .select('SELECT scope_json FROM lm_v14_missions')
                  .single['scope_json']
              as String;
      expect(jsonDecode(encodedScope), containsPair('projectId', ''));
      expect(jsonDecode(encodedScope), containsPair('worldId', ''));
      await tester.ensureVisible(
        find.text('Autoriser les lectures planifiées'),
      );
      await tester.tap(find.text('Autoriser les lectures planifiées'));
      await settleStorage(tester);
      expect(find.textContaining('succeeded'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
