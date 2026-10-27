import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/multimodel/model_panel.dart';
import 'package:litert_edge_demos/living_memory/multimodel/model_registry.dart';
import 'package:litert_edge_demos/living_memory/multimodel/multi_model_engine.dart';

import 'multi_model_engine_test.dart' show Runtime;

void main() {
  testWidgets('model controls show state and disable registration while busy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('panel-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final registry = ModelRegistry(dir);
    final engine = MultiModelEngine(Runtime(), available: () => {});
    final registered = <String>[];
    Widget panel({required bool busy}) => MaterialApp(
      home: Scaffold(
        body: ModelPanel(
          registry: registry,
          engine: engine,
          busy: busy,
          register: registered.add,
          selectMode: (_) {},
          openModels: () {},
        ),
      ),
    );
    await tester.pumpWidget(panel(busy: false));
    expect(find.text('État : Déchargé'), findsOneWidget);
    expect(find.textContaining('non enregistré'), findsNWidgets(2));
    await tester.tap(find.text('Enregistrer comme E2B'));
    expect(registered, ['e2b']);
    await tester.pumpWidget(panel(busy: true));
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Enregistrer comme E4B'),
    );
    expect(button.onPressed, isNull);
  });
}
