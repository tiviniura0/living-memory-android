import 'dart:io';

import 'package:test/test.dart';
import 'package:world_headless/scenario_runner.dart';

void main() {
  test('headless_matches_step_by_step', () {
    final initial = WorldFactory.create('w', WorldConfig(), 5),
        c = WorldCore(initial);
    final r = SimulationRunner(c, LocalAgentRunner(c));
    for (var i = 0; i < 20; i++) r.advance(1);
    expect(ScenarioRunner().run(initial, 20), c.snapshot());
  });
  test('save_resume_same_hash', () {
    final s = WorldFactory.create('w', WorldConfig(), 5), r = ScenarioRunner();
    final middle = r.run(s, 10);
    expect(middle.state.tick, 10);
    expect(
      r.run(WorldCodec.decode(WorldCodec.encode(middle.state)), 10),
      r.run(s, 20),
    );
  });
  test('invalid_input_exit_2', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/world_headless.dart',
      '--ticks',
      '-1',
    ]);
    expect(result.exitCode, 2);
  });
}
