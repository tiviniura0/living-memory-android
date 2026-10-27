import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:world_contracts/world_contracts.dart';
Map<String,dynamic> fixture()=>jsonDecode(File('../../fixtures/world/l1_world.json').readAsStringSync()) as Map<String,dynamic>;
void main(){
 test('orphan_reservation_rejected',(){final s=fixture();s['resources'][0]['reservationAgentId']='a1';s['resources'][0]['reservationUntilTick']=4;expect(()=>WorldCodec.decode(jsonEncode(s)),throwsFormatException);});
 test('snapshot_cannot_be_mutated',(){final s=WorldCodec.decode(jsonEncode(fixture()));expect(()=>s.data['tick']=100,throwsUnsupportedError);expect(()=>(s.data['agents'] as List).clear(),throwsUnsupportedError);expect(()=>(s.data['agents'][0] as Map)['hunger']=0,throwsUnsupportedError);});
}
