import 'package:flutter/material.dart';
import 'package:world_core/world_core.dart';
class CameraController extends ChangeNotifier {
 double zoom=1;Offset origin=Offset.zero;String? following;
 GridPos? toWorld(Offset point)=>const GridPos(0,0);
 void pan(Offset delta){}
 void zoomAt(Offset focal,double factor){}
 void centerOn(GridPos p){}
 void follow(String? id){following=id;}
 void stopFollowing(){}
}
