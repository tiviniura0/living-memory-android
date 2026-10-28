import 'package:flutter/widgets.dart';

import '../world_controller.dart';
import 'lifecycle_logic.dart';

class WorldLifecycle {
  final WorldController controller;
  WorldLifecycle(this.controller);
  Future<void> onState(AppLifecycleState state) async {
    final policy = LifecyclePause(controller.setPaused, controller.save);
    if (state == AppLifecycleState.resumed) {
      policy.resume();
    } else {
      await policy.background();
    }
  }
}
