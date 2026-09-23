import '../../core/performance/performance_metrics.dart';
import '../../domain/language.dart';
import '../../domain/translation_result.dart';
import 'translation_engine.dart';

/// Development-only predictable adapter. Replace with a real offline model adapter.
class MockTranslationEngine implements TranslationEngine {
  bool _initialized = false;
  @override
  bool get isInitialized => _initialized;
  @override
  String get modelVersion => 'development-mock-1.0';

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _initialized = true;
  }

  @override
  Future<void> warmUp() async {
    if (!_initialized) {
      throw StateError('Translation model is not initialized.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 70));
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required Language sourceLanguage,
    required Language targetLanguage,
  }) async {
    if (!_initialized) {
      throw StateError('Translation model is not initialized.');
    }
    if (sourceLanguage == targetLanguage) {
      throw ArgumentError('Source and target must differ.');
    }
    final total = Stopwatch()..start();
    final pre = Stopwatch()..start();
    final cleaned = text.trim();
    pre.stop();
    final inference = Stopwatch()..start();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    inference.stop();
    final post = Stopwatch()..start();
    final label = targetLanguage == Language.santali ? 'Santali' : 'Hindi';
    final output = '[DEVELOPMENT MOCK — $label] $cleaned';
    post.stop();
    total.stop();
    return TranslationResult(
      text: output,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      metrics: TranslationMetrics(
        preprocessing: pre.elapsed,
        inference: inference.elapsed,
        postprocessing: post.elapsed,
        total: total.elapsed,
      ),
    );
  }

  @override
  Future<void> dispose() async => _initialized = false;
}
