class LatencyBenchmark {
  const LatencyBenchmark({
    required this.asrMs,
    required this.translationMs,
    required this.ttsMs,
    required this.totalMs,
    required this.recordedAt,
  });

  final int asrMs;
  final int translationMs;
  final int ttsMs;
  final int totalMs;
  final DateTime recordedAt;

  Map<String, Object?> toMap() => {
    'asrMs': asrMs,
    'translationMs': translationMs,
    'ttsMs': ttsMs,
    'totalMs': totalMs,
    'recordedAt': recordedAt.toIso8601String(),
  };
}
