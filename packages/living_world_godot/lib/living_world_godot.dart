import 'dart:async';

// Compilable RED scaffold; no native event is manufactured.
class LivingWorldGodotController {
  LivingWorldGodotController(this.viewId);
  final int viewId;
  Stream<Map<Object?, Object?>> get events => const Stream.empty();
  Future<void> open() async {}
  Future<void> probe(String nonce) async {}
  Future<void> dispose() async {}
}
