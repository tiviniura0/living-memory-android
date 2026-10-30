import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_world_godot/living_world_godot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  testWidgets('requests a hybrid platform view and routes received status', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final created = <Map<Object?, Object?>>[];
    final nativeCalls = <String>[];
    final received = <Map<Object?, Object?>>[];
    int? viewId;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter/platform_views'), (call) async {
      if (call.method == 'create') {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        created.add(args);
        viewId = args['id'] as int;
        messenger.setMockMethodCallHandler(MethodChannel('living_world/godot/methods/$viewId'), (call) async {
          nativeCalls.add(call.method);
          return null;
        });
        messenger.setMockMethodCallHandler(MethodChannel('living_world/godot/events/$viewId'), (call) async {
          nativeCalls.add('events.${call.method}');
          return null;
        });
      }
      if (call.method == 'resize') return {'width': 400.0, 'height': 400.0};
      return null;
    });
    try {
      await tester.pumpWidget(MaterialApp(home: SizedBox(width: 400, height: 400, child: LivingWorldGodotView(onEvent: received.add))));
      await tester.pumpAndSettle();
      for (var frame = 0; frame < 10 && !nativeCalls.contains('open'); frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Chargement Godot…'), findsOneWidget);
      expect(created, hasLength(1));
      expect(created.single['viewType'], 'living_world/godot_view');
      expect(created.single['hybrid'], true);
      expect(nativeCalls, containsAllInOrder(['events.listen', 'open']));
      // Unit fixture only: it never counts as a native Godot ready proof.
      await messenger.handlePlatformMessage('living_world/godot/events/$viewId', const StandardMethodCodec().encodeSuccessEnvelope({
        'type': 'ready', 'version': '4.5.1.fixture', 'singleton': 'LivingWorldRender',
      }), (_) {});
      await tester.pumpAndSettle();
      for (var frame = 0; frame < 10 && find.text('Godot 4.5.1.fixture').evaluate().isEmpty; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(received, [{'type': 'ready', 'version': '4.5.1.fixture', 'singleton': 'LivingWorldRender'}]);
      expect(find.text('Godot 4.5.1.fixture'), findsOneWidget, reason: 'Native calls: $nativeCalls; received: $received');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      messenger.setMockMethodCallHandler(const MethodChannel('flutter/platform_views'), null);
      if (viewId != null) {
        messenger.setMockMethodCallHandler(MethodChannel('living_world/godot/methods/$viewId'), null);
        messenger.setMockMethodCallHandler(MethodChannel('living_world/godot/events/$viewId'), null);
      }
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('explains the Android-only renderer on unsupported platforms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(const MaterialApp(home: LivingWorldGodotView()));
      expect(find.text('Rendu Godot disponible sur Android'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
