import 'dart:typed_data';

import '../../domain/language.dart';

class SpeechRecognitionResult {
  const SpeechRecognitionResult({
    required this.text,
    required this.languageCode,
    required this.elapsed,
  });

  final String text;
  final String? languageCode;
  final Duration elapsed;
}

class VoiceTranslationResult {
  const VoiceTranslationResult({
    required this.transcript,
    required this.translatedText,
    required this.languageCode,
    required this.elapsed,
  });

  final String transcript;
  final String translatedText;
  final String? languageCode;
  final Duration elapsed;
}

abstract class SpeechToTextEngine {
  Future<SpeechRecognitionResult> transcribe({
    required Uint8List wavAudio,
    required Language language,
    void Function(bool uploadFinished)? onUploadFinished,
  });
}

/// Speech translation performed together by the backend in one request.
abstract class VoiceTranslationEngine {
  Future<VoiceTranslationResult> translateSpeech({
    required Uint8List wavAudio,
    required Language source,
    required Language target,
    void Function(bool uploadFinished)? onUploadFinished,
  });
}
