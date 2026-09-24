import '../core/performance/performance_metrics.dart';
import '../domain/language.dart';
import '../domain/translation_result.dart';
import '../services/translation_cache.dart';
import 'speech/speech_engine.dart';
import 'translation/translation_engine.dart';

enum ModelState { idle, loading, warming, ready, error, disposed }

class ModelManager {
  ModelManager({
    required TranslationEngine translationEngine,
    required SpeechEngine speechEngine,
    TranslationCache? cache,
  })  : _translationEngine = translationEngine,
        _speechEngine = speechEngine,
        cache = cache ?? TranslationCache();
  final TranslationEngine _translationEngine;
  final SpeechEngine _speechEngine;
  final TranslationCache cache;
  ModelState state = ModelState.idle;
  String? errorMessage;
  Duration? modelLoadTime;
  Duration? warmUpTime;
  Duration? lastInferenceTime;
  Duration? lastSpeechTime;
  final List<Duration> _inferenceHistory = [];

  double? get averageInferenceMs => _inferenceHistory.isEmpty
      ? null
      : _inferenceHistory.map((e) => e.inMicroseconds).reduce((a, b) => a + b) /
          _inferenceHistory.length /
          1000;
  String get modelVersion => _translationEngine.modelVersion;

  Future<void> initialize() async {
    if (state == ModelState.ready) return;
    state = ModelState.loading;
    errorMessage = null;
    final load = Stopwatch()..start();
    try {
      await _translationEngine.initialize();
      await Future.wait([
        for (final language in Language.values)
          _speechEngine.initialize(language),
      ]);
      load.stop();
      modelLoadTime = load.elapsed;
      state = ModelState.warming;
      final warm = Stopwatch()..start();
      await _translationEngine.warmUp();
      warm.stop();
      warmUpTime = warm.elapsed;
      state = ModelState.ready;
    } catch (error) {
      load.stop();
      state = ModelState.error;
      errorMessage = 'Could not initialize offline models: $error';
    }
  }

  Future<TranslationResult> translate({
    required String text,
    required Language source,
    required Language target,
  }) async {
    if (state != ModelState.ready) {
      throw StateError(errorMessage ?? 'Offline model is not ready.');
    }
    if (text.trim().isEmpty) throw ArgumentError('Enter text to translate.');
    if (text.runes.length > 2000) {
      throw ArgumentError('Keep input under 2,000 characters.');
    }
    final cached = cache.get(text, source, target);
    if (cached != null) {
      return TranslationResult(
        text: cached.text,
        sourceLanguage: source,
        targetLanguage: target,
        metrics: const TranslationMetrics(
          preprocessing: Duration.zero,
          inference: Duration.zero,
          postprocessing: Duration.zero,
          total: Duration.zero,
          fromCache: true,
        ),
      );
    }
    try {
      final result = await _translationEngine.translate(
        text: text,
        sourceLanguage: source,
        targetLanguage: target,
      );
      cache.put(text, result);
      lastInferenceTime = result.metrics.inference;
      _inferenceHistory.add(result.metrics.inference);
      return result;
    } catch (error) {
      throw StateError('Translation failed: $error');
    }
  }

  Future<void> startSpeech(Language language) async {
    if (!_speechEngine.isAvailable(language)) {
      throw StateError(
        'Offline speech model is unavailable for ${language.label}.',
      );
    }
    await _speechEngine.startRecording(language);
  }

  Future<String> stopSpeech(Language language) async {
    final timer = Stopwatch()..start();
    try {
      final text = await _speechEngine.stopRecordingAndRecognize(language);
      timer.stop();
      lastSpeechTime = timer.elapsed;
      if (text.trim().isEmpty) {
        throw StateError('No speech was detected. Please try again.');
      }
      return text.trim();
    } catch (error) {
      timer.stop();
      throw StateError('Speech recognition failed: $error');
    }
  }

  Future<void> cancelSpeech() => _speechEngine.cancelRecording();
  Future<BenchmarkResult> benchmark(TranslationDirection direction) async {
    const samples = [
      'आपका नाम क्या है?',
      'नमस्ते',
      'कृपया मेरी सहायता करें।',
      'आज मौसम अच्छा है।',
    ];
    final durations = <Duration>[];
    for (final text in samples) {
      final result = await _translationEngine.translate(
        text: text,
        sourceLanguage: direction.source,
        targetLanguage: direction.target,
      );
      durations.add(result.metrics.total);
    }
    return BenchmarkResult(durations);
  }

  Future<void> dispose() async {
    await _speechEngine.dispose();
    await _translationEngine.dispose();
    state = ModelState.disposed;
  }
}
