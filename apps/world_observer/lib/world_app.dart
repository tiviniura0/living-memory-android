import 'dart:io';

import 'package:flutter/material.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

import 'world_controller.dart';
import 'map/camera_controller.dart';
import 'map/world_viewport.dart';
import 'panels/agent_panel.dart';
import 'panels/event_journal.dart';

class WorldApp extends StatefulWidget {
  final WorldController? controller;
  const WorldApp({super.key, this.controller});
  @override
  State<WorldApp> createState() => _WorldAppState();
}

class _WorldAppState extends State<WorldApp> {
  late final WorldController controller;
  final camera = CameraController();
  @override
  void initState() {
    super.initState();
    final c = WorldCore(WorldFactory.create('world1', WorldConfig(), 5));
    controller =
        widget.controller ??
        WorldController(
          c,
          LocalAgentRunner(c),
          CheckpointStore(Directory('world-preview')),
        );
    controller.addListener(_update);
  }

  void _update() {
    if (camera.following != null) {
      final matches = controller.core.snapshot().state.agents.where(
        (a) => a.id == camera.following,
      );
      if (matches.isNotEmpty) camera.centerOn(matches.first.position);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_update);
    if (widget.controller == null) controller.dispose();
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Living World',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff145c55)),
      useMaterial3: true,
    ),
    home: Builder(
      builder: (context) {
        final s = controller.view.value.snapshot.state;
        final selected = s.agents.where(
          (a) => a.id == controller.selectedAgentId,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Living World'),
            actions: [
              IconButton(
                tooltip: 'Journal',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        EventJournal(snapshot: controller.core.snapshot()),
                  ),
                ),
                icon: const Icon(Icons.history),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      const Text('Règles locales'),
                      Text('Tick ${s.tick}'),
                      Text(
                        '${s.agents.length}/${s.config.populationMax} habitants',
                      ),
                      Text(
                        '${controller.effectiveSpeed.toStringAsFixed(1)}× réel',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WorldViewport(
                          controller: controller,
                          camera: camera,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Column(
                          children: [
                            IconButton.filled(
                              tooltip: 'Agrandir',
                              onPressed: () => camera.zoomAt(
                                Offset(
                                  camera.viewport.width / 2,
                                  camera.viewport.height / 2,
                                ),
                                1.25,
                              ),
                              icon: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            IconButton.filled(
                              tooltip: 'Réduire',
                              onPressed: () => camera.zoomAt(
                                Offset(
                                  camera.viewport.width / 2,
                                  camera.viewport.height / 2,
                                ),
                                .8,
                              ),
                              icon: const Icon(Icons.remove),
                            ),
                            const SizedBox(height: 8),
                            IconButton.filled(
                              tooltip: 'Recentrer',
                              onPressed: () =>
                                  camera.centerOn(const GridPos(2, 2)),
                              icon: const Icon(Icons.center_focus_strong),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .37,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected.isNotEmpty)
                          AgentPanel(
                            agent: selected.first,
                            onFollow: () {
                              camera.follow(selected.first.id);
                              camera.centerOn(selected.first.position);
                            },
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: () =>
                                    controller.setPaused(!controller.paused),
                                icon: Icon(
                                  controller.paused
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                ),
                                label: Text(
                                  controller.paused ? 'Reprendre' : 'Pause',
                                ),
                              ),
                              for (final speed in [1, 2, 4])
                                TextButton(
                                  onPressed: () => controller.setSpeed(speed),
                                  child: Text('$speed×'),
                                ),
                              TextButton(
                                onPressed: controller.save,
                                child: const Text('Sauvegarder'),
                              ),
                              TextButton(
                                onPressed: controller.restore,
                                child: const Text('Restaurer'),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Trouver un habitant',
                                onSelected: (id) {
                                  controller.selectAgent(id);
                                  camera.centerOn(
                                    s.agents
                                        .firstWhere((a) => a.id == id)
                                        .position,
                                  );
                                },
                                itemBuilder: (_) => [
                                  for (final a in s.agents)
                                    PopupMenuItem(
                                      value: a.id,
                                      child: Text(a.name),
                                    ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Habitants'),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _settings(context),
                                child: const Text('Réglages'),
                              ),
                              TextButton(
                                onPressed: () => _transfer(context),
                                child: const Text('Import / export'),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            controller.saveStatus,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  Future<void> _settings(BuildContext context) async {
    final input = TextEditingController(
      text: '${controller.core.snapshot().state.config.populationMax}',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plafond de population'),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '1 à 1000 ; aucun habitant supprimé',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final n = int.tryParse(input.text);
              if (n != null) controller.setPopulationMax(n);
              Navigator.pop(context);
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    input.dispose();
  }

  Future<void> _transfer(BuildContext context) async {
    controller.setPaused(true);
    final input = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sauvegarde portable JSON'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: input,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Coller un export ici. Un import invalide conserve le monde.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              input.text = await controller.exportJson();
            },
            child: const Text('Préparer export'),
          ),
          TextButton(
            onPressed: () async {
              await controller.importJson(input.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Importer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    input.dispose();
  }
}
