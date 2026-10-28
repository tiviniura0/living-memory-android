import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:world_contracts/world_contracts.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('../../fixtures/world/l1_world.json').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  test('action_reference_must_belong_to_actor', () {
    final s = fixture();
    s['agents'][0]['currentAction'] = 'c1';
    s['agents'][1]['currentAction'] = 'c1';
    s['pendingActions'] = [
      {
        'commandId': 'c1',
        'actorId': 'a1',
        'kind': 'rest',
        'arguments': {},
        'startedTick': 0,
        'dueTick': 40,
        'reservedResourceId': null,
        'status': 'pending',
      },
    ];
    s['appliedCommandIds'] = ['c1'];
    expect(() => WorldCodec.decode(jsonEncode(s)), throwsFormatException);
  });
  test('orphan_reservation_rejected', () {
    final s = fixture();
    s['resources'][0]['reservationAgentId'] = 'a1';
    s['resources'][0]['reservationUntilTick'] = 4;
    expect(() => WorldCodec.decode(jsonEncode(s)), throwsFormatException);
  });
  test('snapshot_cannot_be_mutated', () {
    final s = WorldCodec.decode(jsonEncode(fixture()));
    expect(() => s.data['tick'] = 100, throwsUnsupportedError);
    expect(() => (s.data['agents'] as List).clear(), throwsUnsupportedError);
    expect(
      () => (s.data['agents'][0] as Map)['hunger'] = 0,
      throwsUnsupportedError,
    );
  });
}
