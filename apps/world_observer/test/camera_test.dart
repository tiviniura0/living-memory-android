import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_core/world_core.dart';
import 'package:world_observer/map/camera_controller.dart';
import 'package:world_observer/world_app.dart';
void main(){
 test('reach_four_corners',(){final c=CameraController();for(final p in [const GridPos(0,0),const GridPos(63,0),const GridPos(0,63),const GridPos(63,63)]){c.centerOn(p);expect(c.toWorld(const Offset(160,160)),p);}});
 test('pinch_and_buttons_same_bounds',(){final c=CameraController();c.zoomAt(Offset.zero,100);expect(c.zoom,4);c.zoomAt(Offset.zero,.0001);expect(c.zoom,.5);});
 test('pan_stops_follow',(){final c=CameraController()..follow('a1');c.pan(const Offset(10,0));expect(c.following,isNull);});
 testWidgets('large_text_french_controls',(t)async{await t.pumpWidget(const WorldApp());await t.pumpAndSettle();expect(find.text('Règles locales'),findsOneWidget);expect(find.text('Pause'),findsOneWidget);});
}
