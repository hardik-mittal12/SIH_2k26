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
    phase = TranslationPhase.listening;
    error = null;
    notifyListeners();
    try {
      input = await _models.recognize(direction.source);
      phase = TranslationPhase.ready;
      notifyListeners();
      await translate();
      if (metrics != null && _models.lastSpeechTime != null) {
        metrics = TranslationMetrics(
          preprocessing: metrics!.preprocessing,
          inference: metrics!.inference,
          postprocessing: metrics!.postprocessing,
          speechRecognition: _models.lastSpeechTime,
          total: _models.lastSpeechTime! + metrics!.total,
          fromCache: metrics!.fromCache,
        );
        notifyListeners();
      }
    } catch (exception) {
      error = exception.toString().replaceFirst('Bad state: ', '');
      phase = TranslationPhase.error;
      notifyListeners();
    }
  }

  Future<void> stopVoice() async {
    await _models.stopSpeech();
    phase = TranslationPhase.ready;
    notifyListeners();
  }

  Future<void> retry() => boot();
}
