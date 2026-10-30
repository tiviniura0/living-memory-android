import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_world_godot/living_world_godot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(const MethodChannel('living_world/godot/methods/7'), (call) async {
      calls.add(call.method);
      if (call.method == 'probe') expect(call.arguments, {'nonce': 'flutter-scene'});
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('living_world/godot/events/7'), (call) async {
      calls.add('events.${call.method}');
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel('living_world/godot/methods/7'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('living_world/godot/events/7'), null);
  });
  test('subscribes before opening and routes bounded probe to its view', () async {
    final host = LivingWorldGodotController(7);
    final sub = host.events.listen((_) {});
    await host.open();
    await host.probe('flutter-scene');
    expect(calls, ['events.listen', 'open', 'probe']);
    await sub.cancel();
    await host.dispose();
  });
  test('ready is received from the native event channel only', () async {
    final host = LivingWorldGodotController(7);
    final received = <Map<Object?, Object?>>[];
    final sub = host.events.listen(received.add);
    await host.open();
    expect(received, isEmpty);
    await messenger.handlePlatformMessage('living_world/godot/events/7', codec.encodeSuccessEnvelope({
      'type': 'ready', 'version': '4.5.1.test-fixture', 'singleton': 'LivingWorldRender',
    }), (_) {});
    await Future<void>.delayed(Duration.zero);
    expect(received, [{'type': 'ready', 'version': '4.5.1.test-fixture', 'singleton': 'LivingWorldRender'}]);
    await sub.cancel();
    await host.dispose();
  });
  test('closing releases native owner and cancels its event subscription', () async {
    final host = LivingWorldGodotController(7);
    final sub = host.events.listen((_) {});
    await host.open();
    await host.dispose();
    await sub.cancel();
    expect(calls, containsAllInOrder(['events.listen', 'open', 'close', 'events.cancel']));
  });
}
