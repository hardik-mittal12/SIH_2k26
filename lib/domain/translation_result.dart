import '../core/performance/performance_metrics.dart';
import 'language.dart';

class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.metrics,
  });
  final String text;
  final Language sourceLanguage;
  final Language targetLanguage;
  final TranslationMetrics metrics;
}
