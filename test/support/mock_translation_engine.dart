import 'package:santali_setu/domain/language.dart';
import 'package:santali_setu/domain/translation_result.dart';
import 'package:santali_setu/inference/translation/translation_engine.dart';

/// Test-only initialization stub. It deliberately cannot provide translations.
class MockTranslationEngine implements TranslationEngine {
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  String get modelVersion => 'test-only-no-model';

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> warmUp() async {
    if (!_initialized) throw StateError('Test adapter is not initialized.');
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required Language sourceLanguage,
    required Language targetLanguage,
  }) async {
    throw UnsupportedError('Test adapter does not provide translation output.');
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}
