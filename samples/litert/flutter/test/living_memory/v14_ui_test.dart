import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_memory_core/living_memory_core.dart';
import 'package:litert_edge_demos/living_memory/world_memory_panel.dart';

void main() {
  testWidgets('world uses L1 simulation and explicit private then shared memory', (tester) async {
    final dir = Directory.systemTemp.createTempSync('world-panel-');
    final store = MemoryStore.open('${dir.path}/memory.db', profile: 'test', dimension: 2);
    addTearDown(() { store.close(); dir.deleteSync(recursive: true); });
    await tester.pumpWidget(MaterialApp(home: WorldMemoryPanel(store: store,
      embed: (_) async => [1, 0], directory: dir)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Règles locales'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('world-note')), 'SECRET_LAGON42');
    await tester.tap(find.text('Mémoriser pour A'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Souvenir privé enregistré'), findsOneWidget);
    await tester.tap(find.text('Partager avec B'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Publication explicite'), findsOneWidget);
    await tester.tap(find.text('Consulter B'));
    await tester.pumpAndSettle();
    expect(find.textContaining('shared_declaration'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
