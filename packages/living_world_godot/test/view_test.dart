import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_world_godot/living_world_godot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  testWidgets('creates the hybrid native surface and waits for a real event before ready', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final created = <Map<Object?, Object?>>[];
    int? viewId;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter/platform_views'), (call) async {
      if (call.method == 'create') {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        created.add(args);
        viewId = args['id'] as int;
        messenger.setMockMethodCallHandler(MethodChannel('living_world/godot/methods/$viewId'), (_) async => null);
        messenger.setMockMethodCallHandler(MethodChannel('living_world/godot/events/$viewId'), (_) async => null);
      }
      if (call.method == 'resize') return {'width': 400.0, 'height': 400.0};
      return null;
    });
    try {
      await tester.pumpWidget(const MaterialApp(home: SizedBox(width: 400, height: 400, child: LivingWorldGodotView())));
      await tester.pump();
      expect(find.text('Chargement Godot…'), findsOneWidget);
      expect(created, hasLength(1));
      expect(created.single['viewType'], 'living_world/godot_view');
      expect(created.single['hybrid'], true);
      // This unit fixture tests status routing, never native engine execution.
      await messenger.handlePlatformMessage('living_world/godot/events/$viewId', const StandardMethodCodec().encodeSuccessEnvelope({
        'type': 'ready', 'version': '4.5.1.fixture', 'singleton': 'LivingWorldRender',
      }), (_) {});
      await tester.pump();
      expect(find.text('Godot 4.5.1.fixture'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
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
