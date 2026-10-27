import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

import 'world_app.dart';
import 'world_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final dir = await getApplicationSupportDirectory(),
        store = CheckpointStore(Directory('${dir.path}/living-world-v1'));
    final loaded = await store.load();
    final c = WorldCore(
      loaded.snapshot?.state ?? WorldFactory.create('world1', WorldConfig(), 5),
    );
    final controller = WorldController(c, LocalAgentRunner(c), store);
    if (loaded.warnings.isNotEmpty) {
      controller.saveStatus = loaded.warnings.join(' ');
      controller.setPaused(true);
    }
    runApp(WorldApp(controller: controller));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Stockage indisponible. Ferme puis relance Living World. Les fichiers existants sont conservés.',
            ),
          ),
        ),
      ),
    );
  }
}
