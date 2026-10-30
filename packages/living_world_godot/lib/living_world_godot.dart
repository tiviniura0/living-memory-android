import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Per-platform-view transport. No world or memory data enters this smoke API.
class LivingWorldGodotController {
  LivingWorldGodotController(this.viewId)
      : _methods = MethodChannel('living_world/godot/methods/$viewId'),
        _nativeEvents = EventChannel('living_world/godot/events/$viewId');

  final int viewId;
  final MethodChannel _methods;
  final EventChannel _nativeEvents;
  final _events = StreamController<Map<Object?, Object?>>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  Stream<Map<Object?, Object?>> get events => _events.stream;

  Future<void> open() async {
    _subscription ??= _nativeEvents.receiveBroadcastStream().listen(
      (dynamic event) => _events.add(Map<Object?, Object?>.from(event as Map)),
      onError: _events.addError,
    );
    await _methods.invokeMethod<void>('open');
  }

  Future<void> probe(String nonce) =>
      _methods.invokeMethod<void>('probe', {'nonce': nonce});

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    try {
      await _methods.invokeMethod<void>('close');
    } finally {
      await _subscription?.cancel();
      await _events.close();
    }
  }
}

// Compilable widget RED scaffold. No platform surface yet.
class LivingWorldGodotView extends StatelessWidget {
  const LivingWorldGodotView({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}
