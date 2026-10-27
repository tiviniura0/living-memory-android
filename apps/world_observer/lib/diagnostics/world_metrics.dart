class WorldMetrics {
  final List<Map<String, num>> samples = [];
  void add({
    required int tickMicros,
    required int frameMicros,
    required int agents,
    required int actions,
    required int saveBytes,
  }) {
    samples.add({
      'tickMicros': tickMicros,
      'frameMicros': frameMicros,
      'agents': agents,
      'actions': actions,
      'saveBytes': saveBytes,
    });
    if (samples.length > 1000) samples.removeAt(0);
  }

  int get sampleCount => samples.length;
}
