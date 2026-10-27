import 'package:test/test.dart';
import 'package:world_core/world_core.dart';

import 'support.dart';
import 'command_test.dart' show cmd;

void main() {
  test('event_ids_stay_unique_after_retention', () {
    final data = fixtureCore().snapshot().state.toJson();
    data['eventLog'] = [
      for (var i = 0; i < 10000; i++)
        {
          'schemaVersion': 1,
          'eventId': 'e$i',
          'worldId': 'world1',
          'tick': 0,
          'revision': 0,
          'actorId': 'a1',
          'kind': 'moved',
          'payload': {},
          'commandId': null,
          'observedBy': ['a1'],
        },
    ];
    final c = WorldCore(WorldState(data));
    c.submit(cmd(c, kind: ActionKind.gather, args: {'resourceId': 'food1'}));
    expect(
      () => WorldCodec.decode(WorldCodec.encode(c.snapshot().state)),
      returnsNormally,
    );
  });
}
