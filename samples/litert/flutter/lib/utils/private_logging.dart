import 'dart:async';

import 'package:flutter/foundation.dart';

/// Install before plugin initialization. Runtime errors can embed prompts,
/// paths or signed URLs; console sinks never receive their content. The zone
/// also covers future callbacks and third-party Dart print calls.
/// Native libraries have separate logging policies and require device checks.
Future<void> runPrivateApplication(Future<void> Function() start) async {
  debugPrint = (String? message, {int? wrapWidth}) {};
  FlutterError.onError = (details) {};
  PlatformDispatcher.instance.onError = (error, stack) => true;
  await runZoned(
    start,
    zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
  );
}
