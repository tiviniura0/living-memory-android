import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/context_lifecycle_manager.dart';
import 'package:litert_edge_demos/living_memory/context_panel.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';

void main() {
  for (final width in [375.0, 800.0]) {
    testWidgets('context controls fit width $width and large dark text', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('context-layout-');
      final store = MemoryStore.open('${dir.path}/m.db', profile: 'test', dimension: 2);
      store.createAgent('aru', 'Aru');
      final manager = ContextLifecycleManager(store, const MemoryScope(agentId: 'aru'));
      final id = manager.startSession();
      manager.append(id, 'user', 'Une décision explicite.', decision: true);
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(),home: MediaQuery(
        data: MediaQueryData(size: Size(width,800),textScaler: const TextScaler.linear(2),disableAnimations: true),
        child: Scaffold(body: SingleChildScrollView(child: ContextPanel(manager: manager,busy: false))),
      )));
      await tester.tap(find.text('Sessions et contexte'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.close();dir.deleteSync(recursive: true);
    });
  }
  testWidgets('memory centre shows restored originals and compaction controls', (tester) async {
    final dir = Directory.systemTemp.createTempSync('context-ui-');
    final store = MemoryStore.open('${dir.path}/m.db', profile: 'test', dimension: 2);
    store.createAgent('aru', 'Aru');
    final manager = ContextLifecycleManager(store, const MemoryScope(agentId: 'aru'));
    final id = manager.startSession();
    manager.append(id, 'user', 'Décision conservée', decision: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: ContextPanel(manager: manager, busy: false),
    ))));
    expect(find.text('Sessions et contexte'), findsOneWidget);
    await tester.tap(find.text('Sessions et contexte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compacter'));
    await tester.pumpAndSettle();
    expect(manager.checkpoints(id), hasLength(1));
    expect(find.textContaining('Décision conservée'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    store.close(); dir.deleteSync(recursive: true);
  });
}
