import 'package:flutter/widgets.dart';

import '../world_controller.dart';

class WorldLifecycle {
  final WorldController controller;
  WorldLifecycle(this.controller);
  Future<void> onState(AppLifecycleState state) async {}
}
