import 'package:flutter/foundation.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

class WorldController extends ChangeNotifier {
  WorldCore core;
  LocalAgentRunner runner;
  final CheckpointStore store;
  late final ValueNotifier<WorldView> view;
  bool paused = false;
  int speed = 1;
  double effectiveSpeed = 0;
  String? selectedAgentId;
  String saveStatus = 'Sauvegarde locale';
  Future<void> _writes = Future.value();
  WorldController(this.core, this.runner, this.store) {
    view = ValueNotifier(WorldView(core.snapshot()));
  }
  void publish() {
    view.value = WorldView(
      core.snapshot(),
      selectedAgentId: selectedAgentId,
      requestedSpeed: speed,
      effectiveSpeed: effectiveSpeed,
    );
    notifyListeners();
  }

  void selectAgent(String? id) {
    selectedAgentId = id;
    publish();
  }

  void setPaused(bool value) {
    paused = value;
    core.setPaused(value);
    publish();
  }

  void setSpeed(int value) {
    if (![1, 2, 4].contains(value)) throw ArgumentError('speed');
    speed = value;
    publish();
  }

  void setPopulationMax(int value) {
    final r = core.setPopulationMax(value);
    if (r.status == ActionStatus.rejected) saveStatus = 'Plafond invalide';
    publish();
  }

  Future<void> save() {
    final snapshot = core.snapshot();
    final task = _writes.then((_) async {
      try {
        await store.save(snapshot);
        saveStatus = 'Sauvegardé · tick ${snapshot.state.tick}';
      } catch (_) {
        saveStatus = 'Sauvegarde impossible — réessayer';
      }
      publish();
    });
    _writes = task;
    return task;
  }

  Future<void> restore() async {
    setPaused(true);
    await _writes;
    final r = await store.load();
    if (r.snapshot != null) {
      core = WorldCore(r.snapshot!.state)..setPaused(true);
      runner = LocalAgentRunner(core);
      selectedAgentId = null;
      saveStatus = r.recovered
          ? 'Sauvegarde précédente restaurée'
          : 'Reprise · tick ${r.snapshot!.state.tick}';
    } else if (r.warnings.isNotEmpty) {
      saveStatus = r.warnings.join(' ');
    }
    publish();
  }

  Future<String> exportJson() async {
    await save();
    return store.exportJson();
  }

  Future<void> importJson(String json, {int? populationMaxOverride}) async {
    setPaused(true);
    await _writes;
    try {
      await store.importJson(
        json,
        populationMaxOverride: populationMaxOverride,
      );
      await restore();
    } catch (_) {
      saveStatus = 'Import refusé — monde conservé';
      publish();
    }
  }

  @override
  void dispose() {
    view.dispose();
    super.dispose();
  }
}
