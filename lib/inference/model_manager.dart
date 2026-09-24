import 'dart:typed_data';

import '../core/performance/performance_metrics.dart';
import '../domain/language.dart';
import '../domain/translation_result.dart';
import '../services/translation_cache.dart';
import 'speech/speech_engine.dart';
import 'speech/speech_to_text_engine.dart';
import 'translation/translation_engine.dart';

enum ModelState { idle, loading, warming, ready, error, disposed }

class ModelManager {
  ModelManager({
    required TranslationEngine translationEngine,
    required SpeechEngine speechEngine,
    required SpeechToTextEngine speechToTextEngine,
    TranslationCache? cache,
  })  : _translationEngine = translationEngine,
        _speechEngine = speechEngine,
        _speechToTextEngine = speechToTextEngine,
        cache = cache ?? TranslationCache();
  final TranslationEngine _translationEngine;
  final SpeechEngine _speechEngine;
  final SpeechToTextEngine _speechToTextEngine;
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
      await Future.wait([
        _translationEngine.initialize(),
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
      errorMessage = 'Could not initialize the Sarvam translation service: $error';
    }
  }

  Future<TranslationResult> translate({
    required String text,
    required Language source,
    required Language target,
  }) async {
    if (state != ModelState.ready) {
      throw StateError(errorMessage ?? 'Sarvam backend is not ready.');
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
    if (state != ModelState.ready) {
      throw StateError(errorMessage ?? 'The translation service is not ready.');
    }
    if (!_speechEngine.isAvailable(language)) {
      throw StateError(
        'Microphone capture is unavailable for ${language.label}.',
      );
    }
    await _speechEngine.startRecording(language);
  }

  Future<Uint8List> stopSpeech(Language language) async {
    try {
      final audio = await _speechEngine.stopRecording(language);
      if (audio.length <= 44) throw StateError('The recording was empty. Please try again.');
      return audio;
    } catch (error) {
      throw StateError('Recording failed: $error');
    }
  }

  Future<SpeechRecognitionResult> transcribe({
    required Uint8List wavAudio,
    required Language language,
    void Function(bool uploadFinished)? onUploadFinished,
  }) async {
    if (state != ModelState.ready) {
      throw StateError(errorMessage ?? 'The Sarvam backend is not ready.');
    }
    final timer = Stopwatch()..start();
    try {
      final result = await _speechToTextEngine.transcribe(
        wavAudio: wavAudio,
        language: language,
        onUploadFinished: onUploadFinished,
      );
      timer.stop();
      lastSpeechTime = result.elapsed == Duration.zero ? timer.elapsed : result.elapsed;
      if (result.text.trim().isEmpty) throw StateError('No speech was detected. Please try again.');
      return result;
    } catch (error) {
      timer.stop();
      throw StateError('Speech recognition failed: $error');
    }
  }

  Future<VoiceTranslationResult> translateSpeech({
    required Uint8List wavAudio,
    required Language source,
    required Language target,
    void Function(bool uploadFinished)? onUploadFinished,
  }) async {
    if (state != ModelState.ready) {
      throw StateError(errorMessage ?? 'The Sarvam backend is not ready.');
    }
    try {
      return await _speechToTextEngine.translateSpeech(
        wavAudio: wavAudio,
        source: source,
        target: target,
        onUploadFinished: onUploadFinished,
      );
    } catch (error) {
      throw StateError('Speech translation failed: $error');
    }
  }

  Future<void> cancelSpeech() => _speechEngine.cancelRecording();
  Future<void> dispose() async {
    await _speechEngine.dispose();
    await _translationEngine.dispose();
    state = ModelState.disposed;
  }
}
