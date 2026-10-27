import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';
import 'package:world_observer/world_controller.dart';
import 'package:world_observer/map/camera_controller.dart';
import 'package:world_observer/map/world_viewport.dart';
import 'package:world_observer/world_app.dart';

void main() {
  late WorldController controller;
  late CameraController camera;
  setUp(() {
    final core = WorldCore(WorldFactory.create('world1', WorldConfig(), 5));
    controller = WorldController(
      core,
      LocalAgentRunner(core),
      CheckpointStore(Directory('unused-selection-store')),
    );
    camera = CameraController();
  });
  tearDown(() {
    controller.dispose();
    camera.dispose();
  });
  testWidgets('drag_does_not_select', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldViewport(controller: controller, camera: camera),
        ),
      ),
    );
    final before = controller.core.snapshot();
    await t.drag(find.byKey(const Key('world-map')), const Offset(30, 0));
    await t.pump();
    expect(controller.selectedAgentId, isNull);
    expect(controller.core.snapshot(), before);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('tap_after_zoom_selects_expected', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldViewport(controller: controller, camera: camera),
        ),
      ),
    );
    camera.zoomAt(Offset.zero, 2);
    await t.pump();
    final offset =
        t.getTopLeft(find.byKey(const Key('world-map'))) +
        camera.origin +
        Offset(
          CameraController.cell * camera.zoom / 2,
          CameraController.cell * camera.zoom / 2,
        );
    await t.tapAt(offset);
    await t.pump();
    expect(controller.selectedAgentId, 'a1');
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('large_text_french_controls_portrait_and_landscape', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in [const Size(412, 900), const Size(900, 412)]) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(WorldApp(key: ValueKey(size), controller: controller));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('Règles locales'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    }
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
}
