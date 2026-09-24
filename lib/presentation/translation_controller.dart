import 'package:flutter/foundation.dart';

import '../core/performance/performance_metrics.dart';
import '../domain/language.dart';
import '../inference/model_manager.dart';
import '../services/permission_service.dart';

enum TranslationPhase { booting, ready, translating, listening, error }

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

  Future<void> boot() async {
    await _models.initialize();
    phase = _models.state == ModelState.ready
        ? TranslationPhase.ready
        : TranslationPhase.error;
    error = _models.errorMessage;
    notifyListeners();
  }

  void updateInput(String value) => input = value;
  void swap() {
    direction = direction.swapped();
    final oldInput = input;
    input = output;
    output = oldInput;
    metrics = null;
    error = null;
    notifyListeners();
  }

  Future<void> translate() async {
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
      phase = TranslationPhase.ready;
    } catch (exception) {
      error = exception.toString().replaceFirst('Bad state: ', '');
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  Future<void> startVoice() async {
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
      phase = TranslationPhase.listening;
    } catch (exception) {
      error = exception.toString().replaceFirst('Bad state: ', '');
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  Future<void> stopVoice() async {
    if (phase != TranslationPhase.listening) return;
    phase = TranslationPhase.translating;
    error = null;
    notifyListeners();
    try {
      input = await _models.stopSpeech(direction.source);
      final speechDuration = _models.lastSpeechTime;
      // Keep the transcript visible if the ASR or translation stage fails.
      final result = await _models.translate(
        text: input,
        source: direction.source,
        target: direction.target,
      );
      output = result.text;
      metrics = TranslationMetrics(
        preprocessing: result.metrics.preprocessing,
        inference: result.metrics.inference,
        postprocessing: result.metrics.postprocessing,
        speechRecognition: speechDuration,
        total: (speechDuration ?? Duration.zero) + result.metrics.total,
        fromCache: result.metrics.fromCache,
      );
      phase = TranslationPhase.ready;
    } catch (exception) {
      error = exception.toString().replaceFirst('Bad state: ', '');
      phase = TranslationPhase.error;
    }
    notifyListeners();
  }

  Future<void> retry() => boot();
}
