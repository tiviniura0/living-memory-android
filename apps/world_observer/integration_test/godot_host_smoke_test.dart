import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:world_observer/godot_host_smoke.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Flutter Android Godot ready and bidirectional probe', (
    tester,
  ) async {
    final received = <Map<Object?, Object?>>[];
    await tester.pumpWidget(GodotHostSmokeApp(onEvent: received.add));
    Future<Map<Object?, Object?>> waitFor(String type) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        for (final event in received) {
          if (event['type'] == type) return event;
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
      throw TestFailure('No real Godot $type event. Native events: $received');
    }

    try {
      final ready = await waitFor('ready');
      expect(ready['version'], startsWith('4.5.1'));
      expect(ready['singleton'], 'LivingWorldRender');
      final surface = tester.widget<AndroidViewSurface>(
        find.byType(AndroidViewSurface),
      );
      await MethodChannel(
        'living_world/godot/methods/${surface.controller.viewId}',
      ).invokeMethod<void>('probe', {'nonce': 'flutter-to-godot'});
      expect((await waitFor('probe'))['nonce'], 'flutter-to-godot');
      // The CI collector screenshots the actual composited screen while this
      // real Flutter PlatformView remains visible, then verifies Godot's marker.
      // Ready/probe alone cannot detect a Flutter surface occluding Godot.
      debugPrint('GODOT_CANVAS_CAPTURE_READY');
      await Future<void>.delayed(const Duration(seconds: 20));
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
