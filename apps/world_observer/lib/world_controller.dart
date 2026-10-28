import 'package:flutter/foundation.dart';
import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

import 'runtime/world_session.dart';

class WorldController extends ChangeNotifier {
  late final WorldSession session;
  late final ValueNotifier<WorldView> view;
  String? selectedAgentId;
  WorldController(
    WorldCore core,
    LocalAgentRunner runner,
    CheckpointStore store,
  ) {
    session = WorldSession(core, runner, store);
    view = ValueNotifier(WorldView(core.snapshot()));
    session.onChange = publish;
  }
  WorldCore get core => session.core;
  LocalAgentRunner get runner => session.runner;
  CheckpointStore get store => session.store;
  bool get paused => session.paused;
  int get speed => session.speed;
  double get effectiveSpeed => session.effectiveSpeed;
  String get saveStatus => session.saveStatus;
  set saveStatus(String value) => session.saveStatus = value;
  void publish() {
    if (selectedAgentId != null &&
        !core.snapshot().state.agents.any((a) => a.id == selectedAgentId))
      selectedAgentId = null;
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

  void setPaused(bool value) => session.setPaused(value);
  void setSpeed(int value) => session.setSpeed(value);
  void setPopulationMax(int value) {
    final r = core.setPopulationMax(value);
    if (r.status == ActionStatus.rejected) saveStatus = 'Plafond invalide';
    publish();
  }

  void advance(Duration elapsed) => session.advance(elapsed);
  Future<void> save() => session.save();
  Future<void> restore() => session.restore();
  Future<String> exportJson() => session.exportJson();
  Future<void> importJson(String json, {int? populationMaxOverride}) =>
      session.importJson(json, populationMaxOverride: populationMaxOverride);
  Future<void> importWithConsent(
    String json,
    Future<bool> Function(int cap, int population) confirm,
  ) => session.importWithConsent(json, confirm);
  @override
  void dispose() {
    session.onChange = null;
    view.dispose();
    super.dispose();
  }
}
