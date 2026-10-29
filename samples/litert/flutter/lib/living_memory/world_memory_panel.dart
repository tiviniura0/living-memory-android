import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:flutter/material.dart';
import 'package:living_memory_core/living_memory_core.dart';
import 'package:living_world_memory/living_world_memory.dart';
import 'package:path_provider/path_provider.dart';
import 'package:world_observer/map/camera_controller.dart';
import 'package:world_observer/map/world_viewport.dart';
import 'package:world_observer/world_controller.dart';
import 'package:world_persistence/world_persistence.dart';

import '../config/knowledge_config.dart';
import 'memory_key.dart';

/// A host for the existing L1 modules, with its own memory file. No access to
/// another Android application's storage and no copy of simulation rules.
class WorldMemoryScreen extends StatefulWidget {
  const WorldMemoryScreen({super.key, required this.embed, this.embedQuery});
  final Future<List<double>> Function(String) embed;
  final Future<List<double>> Function(String)? embedQuery;
  @override
  State<WorldMemoryScreen> createState() => _WorldMemoryScreenState();
}

class _WorldMemoryScreenState extends State<WorldMemoryScreen> {
  MemoryStore? _store;
  Directory? _directory;
  String _status = 'Ouverture de l’espace du monde…';
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final root = await getApplicationSupportDirectory();
      final path = '${root.path}/living-world-memory-v1.db';
      final key = await MemoryKey.forDatabase(path);
      if (!mounted) {
        return;
      }
      final store = MemoryStore.open(
        path,
        profile: kKbEmbeddingProfileId,
        dimension: kKbEmbeddingDimension,
        encryptionKey: key,
      );
      setState(() {
        _store = store;
        _directory = Directory('${root.path}/living-world-v14');
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Espace du monde inaccessible. Données conservées.',
        );
      }
    }
  }

  @override
  void dispose() {
    _store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _store == null
      ? Scaffold(
          appBar: AppBar(title: const Text('Living World · mémoire')),
          body: Center(child: Text(_status)),
        )
      : WorldMemoryPanel(
          store: _store!,
          embed: widget.embed,
          embedQuery: widget.embedQuery,
          directory: _directory!,
        );
}

class WorldMemoryPanel extends StatefulWidget {
  const WorldMemoryPanel({
    super.key,
    required this.store,
    required this.embed,
    required this.directory,
    this.embedQuery,
  });
  final MemoryStore store;
  final Future<List<double>> Function(String) embed;
  final Future<List<double>> Function(String)? embedQuery;
  final Directory directory;
  @override
  State<WorldMemoryPanel> createState() => _WorldMemoryPanelState();
}

class _WorldMemoryPanelState extends State<WorldMemoryPanel> {
  final _note = TextEditingController();
  final _camera = CameraController();
  WorldController? _controller;
  LivingWorldMemory? _memory;
  bool _busy = true;
  bool _needsSync = true;
  String _status = 'Chargement du monde L1…';
  String? _lastSource;
  List<MemoryReference> _references = [];

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    await _run(() async {
      final checkpoint = CheckpointStore(widget.directory);
      final loaded = await checkpoint.load();
      if (loaded.snapshot == null && loaded.warnings.isNotEmpty) {
        throw StateError('Checkpoint invalide : aucune réinitialisation.');
      }
      final core = WorldCore(
        loaded.snapshot?.state ??
            WorldFactory.create('world1', WorldConfig(), 2),
      );
      if (!mounted) {
        return;
      }
      _controller = WorldController(core, LocalAgentRunner(core), checkpoint)
        ..setPaused(true);
      _memory = LivingWorldMemory(
        store: widget.store,
        worldId: core.snapshot().state.worldId,
        agentIds: core.snapshot().state.agents.map((a) => a.id).toSet(),
        embed: widget.embed,
        embedQuery: widget.embedQuery,
      );
      // Retry the committed snapshot before allowing another tick. A failure
      // pins this checkpoint in the host; it never advances past unacked work.
      await _sync();
      _status = loaded.warnings.isEmpty
          ? 'Monde L1 prêt ; aucun modèle génératif actif.'
          : loaded.warnings.join(' ');
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (mounted) {
      setState(() => _busy = true);
    }
    try {
      await operation();
    } catch (_) {
      _status = 'Opération interrompue. Données conservées ; réessaie la synchronisation.';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sync() async {
    _needsSync = true;
    final controller = _controller!;
    // Propagate a failed save: the existing UI save() intentionally reports
    // failure in a status; the bridge requires a committed checkpoint.
    await controller.store.save(controller.core.snapshot());
    await _memory!.ingestSnapshot(controller.core.snapshot());
    _needsSync = false;
  }

  Future<void> _advance() => _run(() async {
    if (_needsSync) {
      throw StateError('Synchronisation requise.');
    }
    final controller = _controller!;
    controller.core.setPaused(false);
    try {
      SimulationRunner(controller.core, controller.runner).advance(12);
    } finally {
      controller.core.setPaused(true);
    }
    controller.publish();
    await _sync();
    _status =
        'Événements perçus mémorisés · tick ${controller.core.snapshot().state.tick}';
  });
  Future<void> _remember() => _run(() async {
    final text = _note.text.trim();
    if (text.isEmpty) {
      throw const FormatException('Note vide.');
    }
    final state = _controller!.core.snapshot().state;
    final result = await _memory!.ingest(
      PerceivedEvent({
        'schemaVersion': 1,
        'worldId': state.worldId,
        'agentId': 'a1',
        'eventId': 'note_${DateTime.now().microsecondsSinceEpoch}',
        'tick': state.tick,
        'sourceRevision': state.revision,
        'kind': 'declaration',
        'text': text,
        'parentEventIds': <String>[],
        'observedBy': ['a1'],
      }),
    );
    _lastSource = result.data['sourceId'] as String;
    _references = [];
    _status = 'Souvenir privé enregistré pour A · déclaration non vérifiée.';
  });
  Future<void> _share() => _run(() async {
    await _memory!.publish(
      agentId: 'a1',
      sourceId: _lastSource!,
      recipients: {'a2'},
    );
    _status = 'Publication explicite de A vers B. Les copies citées restent indépendantes.';
  });
  Future<void> _recallB() => _run(() async {
    _references = await _memory!.recall(
      RecallQuery({
        'schemaVersion': 1,
        'worldId': _controller!.core.snapshot().state.worldId,
        'agentId': 'a2',
        'text': _note.text.trim().isEmpty ? 'move' : _note.text.trim(),
        'topK': 6,
        'contextBudgetBytes': 4096,
      }),
    );
    _status = '${_references.length} souvenir(s) autorisé(s) pour B.';
  });
  @override
  void dispose() {
    _controller?.dispose();
    _camera.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Living World · mémoire V1.4')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Règles locales · moteur L1 existant · mémoire sur cet appareil',
            ),
            if (controller != null) ...[
              SizedBox(
                height: 220,
                child: WorldViewport(controller: controller, camera: _camera),
              ),
              Text(
                'Tick ${controller.core.snapshot().state.tick} · monde en pause entre les actions',
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: !_busy && !_needsSync ? _advance : null,
                    child: const Text('Avancer 12 ticks'),
                  ),
                  OutlinedButton(
                    onPressed: !_busy ? () => _run(_sync) : null,
                    child: const Text('Réessayer la synchronisation'),
                  ),
                ],
              ),
              const Text(
                'A et B gardent des mémoires privées. Seule une publication ouvre un souvenir à B.',
              ),
              TextField(
                key: const Key('world-note'),
                controller: _note,
                maxLength: 1024,
                decoration: const InputDecoration(
                  labelText: 'Déclaration privée de A',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: !_busy ? _remember : null,
                    child: const Text('Mémoriser pour A'),
                  ),
                  OutlinedButton(
                    onPressed: !_busy && _lastSource != null ? _share : null,
                    child: const Text('Partager avec B'),
                  ),
                  OutlinedButton(
                    onPressed: !_busy ? _recallB : null,
                    child: const Text('Consulter B'),
                  ),
                  if (_lastSource != null)
                    OutlinedButton(
                      onPressed: !_busy
                          ? () => _run(() async {
                              await _memory!.revoke(
                                agentId: 'a1',
                                sourceId: _lastSource!,
                              );
                              _references = [];
                              _status = 'Publication révoquée.';
                            })
                          : null,
                      child: const Text('Révoquer le partage'),
                    ),
                ],
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            Semantics(liveRegion: true, child: Text(_status)),
            for (final reference in _references)
              ListTile(
                title: Text(reference.data['text'] as String),
                subtitle: Text(
                  '${reference.data['status']} · tick ${reference.data['tick']} · source ${reference.data['sourceEventIds']}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
