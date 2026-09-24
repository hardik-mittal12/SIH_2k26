import '../../core/performance/performance_metrics.dart';
import '../../domain/language.dart';
import '../../domain/translation_result.dart';
import '../../services/sarvam_backend_client.dart';
import 'translation_engine.dart';

class SarvamTranslationEngine implements TranslationEngine {
  SarvamTranslationEngine(this._backend);
  final SarvamBackendClient _backend;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  String get modelVersion => 'sarvam-translate:v1 via backend';

  @override
  Future<void> initialize() async {
    await _backend.checkReady();
    _initialized = true;
  }

  @override
  Future<void> warmUp() async {
    if (!_initialized) throw StateError('Sarvam backend is not configured.');
    // No paid inference call is made just to warm up a stateless hosted API.
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required Language sourceLanguage,
    required Language targetLanguage,
  }) async {
    if (!_initialized) throw StateError('Sarvam backend is not configured.');
    if (sourceLanguage == targetLanguage) {
      throw ArgumentError('Source and target languages must differ.');
    }
    final total = Stopwatch()..start();
    final pre = Stopwatch()..start();
    final cleaned = text.trim();
    if (cleaned.isEmpty) throw ArgumentError('Enter text to translate.');
    if (cleaned.runes.length > 2_000) {
      throw ArgumentError('Keep translated text under 2,000 characters.');
    }
    pre.stop();
    final inference = Stopwatch()..start();
    final response = await _backend.translate(
      text: cleaned,
      source: sourceLanguage,
      target: targetLanguage,
    );
    inference.stop();
    total.stop();
    return TranslationResult(
      text: response['translatedText']! as String,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      metrics: TranslationMetrics(
        preprocessing: pre.elapsed,
        inference: inference.elapsed,
        postprocessing: Duration.zero,
        total: total.elapsed,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}
