import 'package:flutter/material.dart';

import '../world_controller.dart';
import 'camera_controller.dart';
import 'world_painter.dart';

class WorldViewport extends StatefulWidget {
  final WorldController controller;
  final CameraController camera;
  const WorldViewport({
    super.key,
    required this.controller,
    required this.camera,
  });
  @override
  State<WorldViewport> createState() => _WorldViewportState();
}

class _WorldViewportState extends State<WorldViewport> {
  Offset? down;
  bool moved = false, multi = false;
  int pointers = 0;
  double previousScale = 1;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final camera = widget.camera;
      camera.viewport = box.biggest;
      final s = widget.controller.view.value.snapshot.state;
      camera.width = s.config.width;
      camera.height = s.config.height;
      return Listener(
        onPointerDown: (e) {
          pointers++;
          if (pointers > 1)
            multi = true;
          else {
            down = e.localPosition;
            moved = false;
            multi = false;
          }
        },
        onPointerMove: (e) {
          if (down != null && (e.localPosition - down!).distance > 8)
            moved = true;
        },
        onPointerUp: (e) {
          pointers--;
          if (!moved && !multi && down != null) {
            final p = camera.toWorld(e.localPosition);
            final agents = s.agents.where((a) => a.position == p);
            widget.controller.selectAgent(
              agents.isEmpty ? null : agents.last.id,
            );
          }
          if (pointers == 0) down = null;
        },
        onPointerCancel: (_) {
          pointers = 0;
          down = null;
          moved = true;
        },
        child: GestureDetector(
          onScaleStart: (_) {
            previousScale = 1;
          },
          onScaleUpdate: (d) {
            if (d.scale != previousScale) {
              camera.zoomAt(d.localFocalPoint, d.scale / previousScale);
              previousScale = d.scale;
            }
            if (d.focalPointDelta != Offset.zero) camera.pan(d.focalPointDelta);
          },
          child: AnimatedBuilder(
            animation: camera,
            builder: (context, _) => CustomPaint(
              key: const Key('world-map'),
              painter: WorldPainter(
                widget.controller.view.value.snapshot,
                camera,
                widget.controller.selectedAgentId,
              ),
              size: box.biggest,
            ),
          ),
        ),
      );
    },
  );
}
