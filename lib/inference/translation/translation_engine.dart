import '../../domain/language.dart';
import '../../domain/translation_result.dart';

abstract class TranslationEngine {
  Future<void> initialize();
  Future<void> warmUp();
  Future<TranslationResult> translate({
    required String text,
    required Language sourceLanguage,
    required Language targetLanguage,
  });
  Future<void> dispose();
  bool get isInitialized;
  String get modelVersion;
}
