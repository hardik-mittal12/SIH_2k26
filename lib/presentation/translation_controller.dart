import 'package:flutter/foundation.dart';

import '../core/performance/performance_metrics.dart';
import '../domain/language.dart';
import '../inference/model_manager.dart';
import '../services/permission_service.dart';

enum TranslationPhase {
  booting,
  idle,
  recording,
  uploading,
  transcribing,
  translating,
  success,
  error,
}

class TranslationController extends ChangeNotifier {
  TranslationController(this._models, this._permissions);
  final ModelManager _models;
  final MicrophonePermissionService _permissions;
  TranslationDirection direction = const TranslationDirection(
    Language.hindi,
    Language.santali,
  );
  TranslationPhase phase = TranslationPhase.booting;
  String input = '';
  String output = '';
  String? error;
  TranslationMetrics? metrics;
  ModelManager get models => _models;

  bool get isBusy => const {
        TranslationPhase.booting,
        TranslationPhase.recording,
        TranslationPhase.uploading,
        TranslationPhase.transcribing,
        TranslationPhase.translating,
      }.contains(phase);

  Future<void> boot() async {
    phase = TranslationPhase.booting;
    error = null;
    notifyListeners();
    await _models.initialize();
    phase = _models.state == ModelState.ready
        ? TranslationPhase.idle
        : TranslationPhase.error;
    error = _models.errorMessage == null
        ? null
        : _userMessage(_models.errorMessage!);
    notifyListeners();
  }

  void updateInput(String value) {
    input = value;
    if (phase == TranslationPhase.success) {
      phase = TranslationPhase.idle;
      notifyListeners();
    }
  }

  void clear() {
    if (isBusy) return;
    input = '';
    output = '';
    metrics = null;
    if (_models.state == ModelState.ready) {
      error = null;
      phase = TranslationPhase.idle;
    } else {
      error = _userMessage(
        _models.errorMessage ?? 'The translation service is not ready.',
      );
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  void swap() {
    if (isBusy) return;
    direction = direction.swapped();
    final oldInput = input;
    input = output;
    output = oldInput;
    metrics = null;
    if (_models.state == ModelState.ready) {
      error = null;
      phase = TranslationPhase.idle;
    } else {
      error = _userMessage(
        _models.errorMessage ?? 'The translation service is not ready.',
      );
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  Future<void> translate() async {
    if (isBusy) return;
    phase = TranslationPhase.translating;
    error = null;
    notifyListeners();
    try {
      final result = await _models.translate(
        text: input,
        source: direction.source,
        target: direction.target,
      );
      output = result.text;
      metrics = result.metrics;
      phase = TranslationPhase.success;
    } catch (exception) {
      error = _userMessage(exception);
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  Future<void> startVoice() async {
    if (isBusy) return;
    phase = TranslationPhase.booting;
    error = null;
    notifyListeners();
    if (!await _permissions.request()) {
      error =
          'Microphone permission was denied. Enable it in Android Settings to use voice input.';
      phase = TranslationPhase.error;
      notifyListeners();
      return;
    }
    error = null;
    try {
      await _models.startSpeech(direction.source);
      phase = TranslationPhase.recording;
    } catch (exception) {
      error = _userMessage(exception);
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  Future<void> stopVoice() async {
    if (phase != TranslationPhase.recording) return;
    final source = direction.source;
    phase = TranslationPhase.uploading;
    error = null;
    notifyListeners();
    try {
      final audio = await _models.stopSpeech(source);
      final target = source == Language.hindi ? Language.santali : Language.hindi;
      final result = await _models.translateSpeech(
        wavAudio: audio,
        source: source,
        target: target,
        onUploadFinished: (finished) {
          phase = finished
              ? TranslationPhase.transcribing
              : TranslationPhase.uploading;
          notifyListeners();
        },
      );
      input = result.transcript;
      output = result.translatedText;
      metrics = TranslationMetrics(
        preprocessing: Duration.zero,
        inference: result.elapsed,
        postprocessing: Duration.zero,
        speechRecognition: result.elapsed,
        total: result.elapsed,
      );
      phase = TranslationPhase.success;
    } catch (exception) {
      error = _userMessage(exception);
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  String _userMessage(Object error) {
    final message = error
        .toString()
        .replaceAll('Bad state: ', '')
        .replaceAll('Exception: ', '')
        .replaceAll('Could not initialize the Sarvam translation service: ', '')
        .replaceAll('Speech translation failed: ', '')
        .replaceAll('Speech recognition failed: ', '')
        .replaceAll('Recording failed: ', '')
        .replaceAll('Translation failed: ', '');
    if (message.contains('translation service is not configured') ||
        message.contains('server/.env')) {
      return 'The translation service is not ready yet. Please ask the demo host to check the service setup.';
    }
    if (message.contains('EMPTY_RECORDING')) {
      return 'No speech was captured. Move closer to the microphone and try again.';
    }
    if (message.contains('MIC_PERMISSION_DENIED')) {
      return 'Microphone permission is needed. Allow it in your phone settings and try again.';
    }
    if (message.contains('AUDIO_CONFIG_UNAVAILABLE') ||
        message.contains('AUDIO_INIT_FAILED') ||
        message.contains('AUDIO_START_FAILED') ||
        message.contains('PlatformException') ||
        message.contains('MissingPluginException')) {
      return 'The microphone could not be started. Check microphone permission and try again.';
    }
    return message;
  }

  Future<void> retry() => boot();
}
