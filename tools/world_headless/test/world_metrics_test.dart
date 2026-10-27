import 'package:test/test.dart';

import '../../../apps/world_observer/lib/diagnostics/world_metrics.dart';

void main() {
  test('metrics_buffer_bounded', () {
    final m = WorldMetrics();
    for (var i = 0; i < 1001; i++)
      m.add(
        tickMicros: i,
        frameMicros: 0,
        agents: 5,
        actions: 1,
        saveBytes: 100,
      );
    expect(m.sampleCount, 1000);
    expect(m.samples.first['tickMicros'], 1);
  });
}
