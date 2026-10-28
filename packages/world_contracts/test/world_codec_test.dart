import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:world_contracts/world_contracts.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('../../fixtures/world/l1_world.json').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  test('roundtrip_schema1_preserves_state', () {
    final s = WorldState(fixture());
    expect(WorldCodec.decode(WorldCodec.encode(s)), s);
  });
  test('rejects_future_version', () {
    final s = fixture();
    (s['config'] as Map)['schemaVersion'] = 2;
    expect(() => WorldCodec.decode(jsonEncode(s)), throwsFormatException);
  });
  test('rejects_duplicate_agents', () {
    final s = fixture();
    (s['agents'] as List).add(s['agents'][0]);
    expect(() => WorldCodec.decode(jsonEncode(s)), throwsFormatException);
  });
  test('rejects_unknown_command_kind', () {
    expect(
      () => ActionProposal.fromJson({'kind': 'shell'}),
      throwsFormatException,
    );
  });
  test('memory_key_separates_worlds', () {
    expect(memoryAgentKey('w1', 'a'), isNot(memoryAgentKey('w2', 'a')));
    expect(memoryAgentKey('w1', 'a').length, 64);
  });
}
