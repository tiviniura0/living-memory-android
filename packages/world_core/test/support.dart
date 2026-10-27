import 'dart:io';

import 'package:world_core/world_core.dart';

WorldCore fixtureCore() => WorldCore(
  WorldCodec.decode(
    File('../../fixtures/world/l1_world.json').readAsStringSync(),
  ),
);
