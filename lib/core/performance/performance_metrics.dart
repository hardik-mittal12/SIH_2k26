class TranslationMetrics {
  const TranslationMetrics({
    required this.preprocessing,
    required this.inference,
    required this.postprocessing,
    required this.total,
    this.speechRecognition,
    this.fromCache = false,
  });

  final Duration preprocessing;
  final Duration inference;
  final Duration postprocessing;
  final Duration total;
  final Duration? speechRecognition;
  final bool fromCache;

  String get totalLabel =>
      '${(total.inMilliseconds / 1000).toStringAsFixed(2)} sec';
}

class BenchmarkResult {
  const BenchmarkResult(this.samples);
  final List<Duration> samples;
  Duration get min => samples.reduce((a, b) => a < b ? a : b);
  Duration get max => samples.reduce((a, b) => a > b ? a : b);
  Duration get average => Duration(
        microseconds:
            samples.map((x) => x.inMicroseconds).reduce((a, b) => a + b) ~/
                samples.length,
      );
  Duration get p95 {
    final values = samples.toList()..sort();
    return values[((values.length - 1) * .95).ceil()];
  }
}
