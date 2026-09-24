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
    error = _models.errorMessage;
    notifyListeners();
  }

  void updateInput(String value) {
    input = value;
    if (phase == TranslationPhase.success) {
      phase = TranslationPhase.idle;
      notifyListeners();
    }
  }

  void swap() {
    if (isBusy) return;
    direction = direction.swapped();
    final oldInput = input;
    input = output;
    output = oldInput;
    metrics = null;
    error = null;
    phase = TranslationPhase.idle;
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
      final transcription = await _models.transcribe(
        wavAudio: audio,
        language: source,
        onUploadFinished: (finished) {
          phase = finished
              ? TranslationPhase.transcribing
              : TranslationPhase.uploading;
          notifyListeners();
        },
      );
      input = transcription.text;
      phase = TranslationPhase.translating;
      notifyListeners();
      final translated = await _models.translate(
        text: transcription.text,
        source: source,
        target: source == Language.hindi ? Language.santali : Language.hindi,
      );
      output = translated.text;
      metrics = TranslationMetrics(
        preprocessing: translated.metrics.preprocessing,
        inference: translated.metrics.inference,
        postprocessing: translated.metrics.postprocessing,
        speechRecognition: transcription.elapsed,
        total: transcription.elapsed + translated.metrics.total,
        fromCache: translated.metrics.fromCache,
      );
      phase = TranslationPhase.success;
    } catch (exception) {
      error = _userMessage(exception);
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  String _userMessage(Object error) {
    return error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
  }

  Future<void> retry() => boot();
}
