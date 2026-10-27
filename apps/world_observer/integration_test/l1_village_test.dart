import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';
import 'package:world_observer/world_app.dart';
import 'package:world_observer/world_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('l1_complete_loop_restores', (tester) async {
    final directory = await Directory.systemTemp.createTemp('l1-device-recipe');
    final core = WorldCore(WorldFactory.create('recipe', WorldConfig(), 5));
    final controller = WorldController(
      core,
      LocalAgentRunner(core),
      CheckpointStore(directory),
    );
    try {
      await tester.pumpWidget(WorldApp(controller: controller));
      await tester.pump(const Duration(seconds: 1));
      expect(core.snapshot().state.tick, greaterThan(0));
      controller.setPaused(true);
      final before = controller.core.snapshot();
      await controller.save();
      expect((await controller.store.load()).snapshot, before);
      await controller.restore();
      expect(controller.core.snapshot().state.tick, before.state.tick);
      expect(controller.core.snapshot().state.agents, before.state.agents);
      expect(
        controller.core.snapshot().state.resources,
        before.state.resources,
      );
      expect(controller.paused, isTrue);
      expect(find.text('Règles locales'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await directory.delete(recursive: true);
    }
  });
}
