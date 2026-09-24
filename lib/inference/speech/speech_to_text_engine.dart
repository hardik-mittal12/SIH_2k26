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

abstract class SpeechToTextEngine {
  Future<SpeechRecognitionResult> transcribe({
    required Uint8List wavAudio,
    required Language language,
    void Function(bool uploadFinished)? onUploadFinished,
  });
}
