import 'package:agent_runtime/agent_runtime.dart';

class WorldLoop {
  final SimulationRunner runner;
  int speed = 1;
  bool paused = false;
  double effectiveSpeed = 0;
  double _remainingMicros = 0;
  int _windowMicros = 0, _windowTicks = 0;
  WorldLoop(this.runner);
  void setSpeed(int v) {
    if (![1, 2, 4].contains(v)) throw ArgumentError('speed');
    speed = v;
  }

  void setPaused(bool v) {
    paused = v;
    runner.core.setPaused(v);
    _remainingMicros = 0;
    _windowMicros = 0;
    _windowTicks = 0;
    effectiveSpeed = 0;
  }

  int advance(Duration elapsed) {
    if (elapsed.isNegative) throw ArgumentError('elapsed');
    if (paused || runner.core.paused) return 0;
    _remainingMicros += elapsed.inMicroseconds * speed;
    final available = (_remainingMicros / 250000).floor(),
        count = available.clamp(0, 8);
    if (count > 0) {
      runner.advance(count);
      _remainingMicros -= count * 250000;
    }
    _windowMicros += elapsed.inMicroseconds;
    _windowTicks += count;
    if (_windowMicros >= 2000000) {
      effectiveSpeed = _windowTicks / (_windowMicros / 1000000) / 4;
      _windowMicros = 0;
      _windowTicks = 0;
    }
    return count;
  }
}
