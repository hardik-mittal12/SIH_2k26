import 'dart:typed_data';

import '../../domain/language.dart';
import '../../services/sarvam_backend_client.dart';
import 'speech_to_text_engine.dart';

class SarvamSpeechToTextEngine implements SpeechToTextEngine {
  const SarvamSpeechToTextEngine(this._backend);
  final SarvamBackendClient _backend;

  @override
  Future<SpeechRecognitionResult> transcribe({
    required Uint8List wavAudio,
    required Language language,
    void Function(bool uploadFinished)? onUploadFinished,
  }) async {
    final result = await _backend.transcribe(
      wavAudio: wavAudio,
      language: language,
      onStage: (stage) =>
          onUploadFinished?.call(stage == SpeechApiStage.transcribing),
    );
    return SpeechRecognitionResult(
      text: result.text,
      languageCode: result.detectedLanguage,
      elapsed: result.elapsed,
    );
  }

  @override
  Future<VoiceTranslationResult> translateSpeech({
    required Uint8List wavAudio,
    required Language source,
    required Language target,
    void Function(bool uploadFinished)? onUploadFinished,
  }) async {
    final result = await _backend.translateSpeech(
      wavAudio: wavAudio,
      source: source,
      target: target,
      onStage: (stage) =>
          onUploadFinished?.call(stage == SpeechApiStage.transcribing),
    );
    return VoiceTranslationResult(
      transcript: result.transcript,
      translatedText: result.translatedText,
      languageCode: result.detectedLanguage,
      elapsed: result.elapsed,
    );
  }
}
