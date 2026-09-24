import 'dart:typed_data';

import '../../domain/language.dart';

/// Captures device audio only. Recognition is performed by the backend service.
abstract class SpeechEngine {
  Future<void> initialize(Language language);
  bool isAvailable(Language language);
  Future<void> startRecording(Language language);
  Future<Uint8List> stopRecording(Language language);
  Future<void> cancelRecording();
  Future<void> dispose();
}
