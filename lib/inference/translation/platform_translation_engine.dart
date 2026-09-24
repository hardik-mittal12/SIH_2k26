import 'package:flutter/services.dart';

import '../../core/performance/performance_metrics.dart';
import '../../domain/language.dart';
import '../../domain/translation_result.dart';
import 'translation_engine.dart';

/// Android bridge for local IndicTrans2 inference. No fallback/heuristic output
/// is generated: absent model/runtime is exposed as an actionable error.
class PlatformTranslationEngine implements TranslationEngine {
  static const _channel = MethodChannel('org.sih.santali_setu/inference');
  bool _initialized = false;
  String _version = 'IndicTrans2 (not installed)';

  String get _checkpoint => 'ai4bharat/indictrans2-indic-indic-dist-320M';

  @override
  bool get isInitialized => _initialized;

  @override
  String get modelVersion => _version;

  @override
  Future<void> initialize() async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'initializeTranslation',
        {'checkpoint': _checkpoint},
      );
      _initialized = status?['available'] == true;
      _version = status?['modelVersion'] as String? ?? _version;
      if (!_initialized) {
        throw StateError(status?['message'] as String? ??
            'IndicTrans2 model/runtime is not installed on this device.');
      }
    } on PlatformException catch (error) {
      _initialized = false;
      throw StateError(error.message ?? 'Could not initialize IndicTrans2.');
    } on MissingPluginException {
      _initialized = false;
      throw StateError('Native Android IndicTrans2 inference is not installed.');
    }
  }

  @override
  Future<void> warmUp() async {
    if (!_initialized) throw StateError('IndicTrans2 is not initialized.');
    // The native runtime owns model warm-up during initialize.
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required Language sourceLanguage,
    required Language targetLanguage,
  }) async {
    if (!_initialized) throw StateError('IndicTrans2 is not initialized.');
    if (sourceLanguage == targetLanguage) {
      throw ArgumentError('Source and target languages must differ.');
    }
    final total = Stopwatch()..start();
    final pre = Stopwatch()..start();
    final cleaned = text.trim();
    if (cleaned.isEmpty) throw ArgumentError('Enter text to translate.');
    final sourceCode = sourceLanguage == Language.hindi ? 'hin_Deva' : 'sat_Olck';
    final targetCode = targetLanguage == Language.hindi ? 'hin_Deva' : 'sat_Olck';
    pre.stop();
    final inference = Stopwatch()..start();
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'translate',
        {
          'text': cleaned,
          'sourceLanguage': sourceCode,
          'targetLanguage': targetCode,
        },
      );
      inference.stop();
      final output = response?['text'] as String?;
      if (output == null || output.trim().isEmpty) {
        throw StateError('IndicTrans2 returned an empty translation.');
      }
      total.stop();
      return TranslationResult(
        text: output,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        metrics: TranslationMetrics(
          preprocessing: pre.elapsed,
          inference: inference.elapsed,
          postprocessing: Duration.zero,
          total: total.elapsed,
        ),
      );
    } on PlatformException catch (error) {
      inference.stop();
      throw StateError(error.message ?? 'IndicTrans2 translation failed.');
    } on MissingPluginException {
      inference.stop();
      throw StateError('Native Android IndicTrans2 inference is unavailable.');
    }
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}
