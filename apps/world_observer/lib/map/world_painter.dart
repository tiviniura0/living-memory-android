import 'package:flutter/material.dart';
import 'package:world_core/world_core.dart';

import 'camera_controller.dart';

class WorldPainter extends CustomPainter {
  final WorldSnapshot snapshot;
  final CameraController camera;
  final String? selected;
  WorldPainter(this.snapshot, this.camera, this.selected)
    : super(repaint: camera);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff102f36),
    );
    canvas.save();
    canvas.translate(camera.origin.dx, camera.origin.dy);
    canvas.scale(camera.zoom);
    final s = snapshot.state, cell = CameraController.cell;
    final left = (-camera.origin.dx / camera.zoom / cell).floor().clamp(
          0,
          s.config.width,
        ),
        top = (-camera.origin.dy / camera.zoom / cell).floor().clamp(
          0,
          s.config.height,
        ),
        right = ((size.width - camera.origin.dx) / camera.zoom / cell)
            .ceil()
            .clamp(0, s.config.width),
        bottom = ((size.height - camera.origin.dy) / camera.zoom / cell)
            .ceil()
            .clamp(0, s.config.height);
    final rocks = s.blockedCells.toSet();
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final p = GridPos(x, y);
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          Paint()
            ..color = rocks.contains(p)
                ? const Color(0xff6f7d70)
                : ((x + y) % 2 == 0
                      ? const Color(0xffabc58c)
                      : const Color(0xffa4bf83)),
        );
        if (rocks.contains(p))
          canvas.drawOval(
            Rect.fromLTWH(x * cell + 4, y * cell + 5, 16, 13),
            Paint()..color = const Color(0xff526256),
          );
      }
    }
    bool visible(GridPos p) =>
        p.x >= left && p.x < right && p.y >= top && p.y < bottom;
    void label(String text, Offset p, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p);
    }

    for (final r in s.resources) {
      if (!visible(r.position)) continue;
      final p = Offset((r.position.x + .5) * cell, (r.position.y + .5) * cell);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 20, height: 20),
          const Radius.circular(4),
        ),
        Paint()
          ..color = r.food > 0
              ? const Color(0xffce7a35)
              : const Color(0xff777777),
      );
      label('${r.food}', p - const Offset(8, 6), Colors.white);
    }
    for (final a in s.agents) {
      if (!visible(a.position)) continue;
      final p = Offset((a.position.x + .5) * cell, (a.position.y + .5) * cell);
      if (a.id == selected)
        canvas.drawCircle(p, 12, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        9,
        Paint()
          ..color = a.currentAction == null
              ? const Color(0xff315a79)
              : const Color(0xff194c50),
      );
      label(a.id.substring(1), p - const Offset(3, 6), Colors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WorldPainter old) =>
      old.snapshot != snapshot ||
      old.selected != selected ||
      old.camera != camera;
}
