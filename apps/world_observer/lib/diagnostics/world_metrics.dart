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

  int lastFrameMicros = 0;
  int lastSaveBytes = 0;
  Map<String, Object> toJson() => {
    'sampleCount': sampleCount,
    'frameTimingAvailable': lastFrameMicros > 0,
    'lastSaveBytes': lastSaveBytes,
    'samples': samples
        .map((s) => Map<String, num>.unmodifiable(s))
        .toList(growable: false),
  };
  int get sampleCount => samples.length;
}
