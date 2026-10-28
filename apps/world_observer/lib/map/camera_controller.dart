import 'package:flutter/material.dart';
import 'package:world_core/world_core.dart';

class CameraController extends ChangeNotifier {
  double zoom = 1;
  Offset origin = const Offset(100, 100);
  Size viewport = const Size(320, 320);
  int width = 64, height = 64;
  String? following;
  static const cell = 24.0;
  GridPos? toWorld(Offset p) {
    final x = ((p.dx - origin.dx) / (cell * zoom)).floor(),
        y = ((p.dy - origin.dy) / (cell * zoom)).floor();
    return x >= 0 && y >= 0 && x < width && y < height ? GridPos(x, y) : null;
  }

  void _clamp() {
    origin = Offset(
      origin.dx.clamp(
        viewport.width / 2 - width * cell * zoom,
        viewport.width / 2,
      ),
      origin.dy.clamp(
        viewport.height / 2 - height * cell * zoom,
        viewport.height / 2,
      ),
    );
  }

  void pan(Offset delta) {
    following = null;
    origin += delta;
    _clamp();
    notifyListeners();
  }

  void zoomAt(Offset focal, double factor) {
    if (!factor.isFinite || factor <= 0) return;
    final next = (zoom * factor).clamp(.5, 4.0);
    origin = focal - (focal - origin) * (next / zoom);
    zoom = next;
    _clamp();
    notifyListeners();
  }

  void centerOn(GridPos p) {
    origin =
        Offset(viewport.width / 2, viewport.height / 2) -
        Offset((p.x + .5) * cell * zoom, (p.y + .5) * cell * zoom);
    _clamp();
    notifyListeners();
  }

  void follow(String? id) {
    following = id;
    notifyListeners();
  }

  void stopFollowing() {
    following = null;
    notifyListeners();
  }
}
