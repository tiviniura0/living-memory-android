import 'package:agent_runtime/agent_runtime.dart';
import 'package:world_persistence/world_persistence.dart';

import 'world_loop.dart';

// One serialized host session owns persistence and activation of imported worlds.
class WorldSession {
  WorldCore core;
  LocalAgentRunner runner;
  final CheckpointStore store;
  late WorldLoop _loop;
  int _lastAutosaveTick = 0;
  bool paused = false;
  int speed = 1;
  double effectiveSpeed = 0;
  String saveStatus = 'Sauvegarde locale';
  void Function()? onChange;
  Future<void> _writes = Future.value();
  WorldSession(this.core, this.runner, this.store) {
    _loop = WorldLoop(SimulationRunner(core, runner));
  }
  void publish() => onChange?.call();
  void setPaused(bool value) {
    paused = value;
    _loop.setPaused(value);
    effectiveSpeed = 0;
    publish();
  }

  void setSpeed(int value) {
    if (![1, 2, 4].contains(value)) throw ArgumentError('speed');
    speed = value;
    publish();
  }

  void advance(Duration elapsed) {
    _loop.setSpeed(speed);
    final count = _loop.advance(elapsed);
    effectiveSpeed = _loop.effectiveSpeed;
    if (count > 0) {
      publish();
      final tick = core.snapshot().state.tick;
      if (tick - _lastAutosaveTick >= 200) {
        _lastAutosaveTick = tick;
        save();
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<bool> _saveNow() async {
    // Capture only when this operation reaches the queue, after any active import.
    final snapshot = core.snapshot();
    try {
      await store.save(snapshot);
      saveStatus = 'Sauvegardé · tick ${snapshot.state.tick}';
      publish();
      return true;
    } catch (_) {
      saveStatus = 'Sauvegarde impossible — réessayer';
      publish();
      return false;
    }
  }

  Future<void> save() => _serialize(() async {
    await _saveNow();
  });
  Future<void> _restoreNow() async {
    final r = await store.load();
    if (r.snapshot != null) {
      core = WorldCore(r.snapshot!.state)..setPaused(true);
      runner = LocalAgentRunner(core);
      _loop = WorldLoop(SimulationRunner(core, runner))..setPaused(true);
      _lastAutosaveTick = core.snapshot().state.tick;
      saveStatus = r.recovered
          ? 'Sauvegarde précédente restaurée'
          : 'Reprise · tick ${r.snapshot!.state.tick}';
    } else if (r.warnings.isNotEmpty) {
      saveStatus = r.warnings.join(' ');
    }
    publish();
  }

  Future<void> restore() {
    setPaused(true);
    return _serialize(_restoreNow);
  }

  Future<String> exportJson() => _serialize(() async {
    if (!await _saveNow())
      throw StateError('Sauvegarde impossible : export annulé');
    return store.exportJson();
  });
  Future<void> importJson(String json, {int? populationMaxOverride}) {
    setPaused(true);
    return _serialize(() async {
      try {
        await store.importJson(
          json,
          populationMaxOverride: populationMaxOverride,
        );
        await _restoreNow();
      } catch (_) {
        saveStatus = 'Import refusé — monde conservé';
        publish();
      }
    });
  }

  Future<void> importWithConsent(
    String json,
    Future<bool> Function(int cap, int population) confirm,
  ) async {
    // Validate before presenting a consent dialog; never change a cap silently.
    WorldState incoming;
    try {
      incoming = WorldCodec.decode(json);
    } catch (_) {
      saveStatus = 'Import refusé — monde conservé';
      publish();
      return;
    }
    int? override;
    if (incoming.agents.length > incoming.config.populationMax) {
      if (!await confirm(incoming.config.populationMax, incoming.agents.length))
        return;
      override = incoming.agents.length;
    }
    await importJson(json, populationMaxOverride: override);
  }
}
