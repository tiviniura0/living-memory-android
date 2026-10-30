import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Real Android PlatformView, with status coming only from the native scene.
class LivingWorldGodotView extends StatefulWidget {
  const LivingWorldGodotView({super.key, this.onEvent});
  final ValueChanged<Map<Object?, Object?>>? onEvent;
  @override
  State<LivingWorldGodotView> createState() => _LivingWorldGodotViewState();
}

class _LivingWorldGodotViewState extends State<LivingWorldGodotView> {
  LivingWorldGodotController? _controller;
  StreamSubscription<Map<Object?, Object?>>? _subscription;
  Timer? _timeout;
  String? _version;
  String? _error;

  Future<void> _connect(int id) async {
    if (!mounted) return;
    final controller = LivingWorldGodotController(id);
    _controller = controller;
    _subscription = controller.events.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'ready') {
        _timeout?.cancel();
        setState(() => _version = event['version'] as String);
      } else if (event['type'] == 'error') {
        _fail(event['code'].toString());
      }
      widget.onEvent?.call(event);
    }, onError: (Object _) => _fail('native_event_error'));
    _timeout = Timer(const Duration(seconds: 20), () => _fail('startup_timeout'));
    try {
      await controller.open();
    } on PlatformException catch (error) {
      _fail(error.code);
    } on MissingPluginException {
      _fail('native_plugin_unavailable');
    }
  }

  void _fail(String code) {
    _timeout?.cancel();
    if (mounted) setState(() => _error = code);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_controller?.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('Rendu Godot disponible sur Android'));
    }
    return Stack(fit: StackFit.expand, children: [
      PlatformViewLink(
        viewType: 'living_world/godot_view',
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (params) => PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: 'living_world/godot_view',
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(_connect)
          ..create(),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: ColoredBox(
          color: const Color(0xEFFFFFFF),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error != null ? 'Rendu indisponible ($_error)' : _version != null ? 'Godot $_version' : 'Chargement Godot…'),
          ),
        ),
      ),
    ]);
  }
}
