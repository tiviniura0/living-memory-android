import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/context_lifecycle_manager.dart';
import 'package:litert_edge_demos/living_memory/context_panel.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';

class _FailingDeletion extends ContextLifecycleManager {
  _FailingDeletion(super.store, super.scope);
  @override
  void deleteSession(String id) => throw StateError('Synthetic delete failure');
}

void main() {
  for (final width in [375.0, 800.0]) {
    testWidgets('context controls fit width $width and large dark text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('context-layout-');
      final store = MemoryStore.open(
        '${dir.path}/m.db',
        profile: 'test',
        dimension: 2,
      );
      store.createAgent('aru', 'Aru');
      final manager = ContextLifecycleManager(
        store,
        const MemoryScope(agentId: 'aru'),
      );
      final id = manager.startSession();
      manager.append(id, 'user', 'Une décision explicite.', decision: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ContextPanel(manager: manager, busy: false),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sessions et contexte'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.close();
      dir.deleteSync(recursive: true);
    });
  }
  testWidgets(
    'memory centre shows restored originals and compaction controls',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('context-ui-');
      final store = MemoryStore.open(
        '${dir.path}/m.db',
        profile: 'test',
        dimension: 2,
      );
      store.createAgent('aru', 'Aru');
      final manager = ContextLifecycleManager(
        store,
        const MemoryScope(agentId: 'aru'),
      );
      final id = manager.startSession();
      manager.append(id, 'user', 'Décision conservée', decision: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContextPanel(manager: manager, busy: false),
            ),
          ),
        ),
      );
      expect(find.text('Sessions et contexte'), findsOneWidget);
      await tester.tap(find.text('Sessions et contexte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compacter'));
      await tester.pumpAndSettle();
      expect(manager.checkpoints(id), hasLength(1));
      expect(find.textContaining('Décision conservée'), findsWidgets);
      await tester.ensureVisible(find.text('Supprimer cette session'));
      await tester.tap(find.text('Supprimer cette session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(manager.sessions(), hasLength(1));
      await tester.tap(find.text('Supprimer cette session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();
      expect(manager.sessions(), isEmpty);
      expect(find.textContaining('Décision conservée'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.close();
      dir.deleteSync(recursive: true);
    },
  );
  testWidgets(
    'failed deletion keeps the session and does not clear parent view',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('failed-delete-');
      final store = MemoryStore.open(
        '${dir.path}/m.db',
        profile: 'test',
        dimension: 2,
      );
      addTearDown(() {
        store.close();
        dir.deleteSync(recursive: true);
      });
      store.createAgent('a', 'A');
      final manager = _FailingDeletion(store, const MemoryScope(agentId: 'a'));
      manager.startSession();
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContextPanel(
                manager: manager,
                busy: false,
                onDeleted: () {
                  cleared = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sessions et contexte'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Supprimer cette session'));
      await tester.tap(find.text('Supprimer cette session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();
      expect(manager.sessions(), hasLength(1));
      expect(cleared, isFalse);
      expect(find.textContaining('Synthetic delete failure'), findsOneWidget);
    },
  );
}
