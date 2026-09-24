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
      onStage: (stage) => onUploadFinished?.call(stage == SpeechApiStage.transcribing),
    );
    return SpeechRecognitionResult(
      text: result.text,
      languageCode: result.detectedLanguage,
      elapsed: result.elapsed,
    );
  }
}
