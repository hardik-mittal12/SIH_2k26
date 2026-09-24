import '../../domain/language.dart';

/// Speech adapter contract. Recording returns real captured audio; recognition
/// must be supplied by an installed local model/runtime, never a canned result.
abstract class SpeechEngine {
  Future<void> initialize(Language language);
  bool isAvailable(Language language);
  Future<void> startRecording(Language language);
  Future<String> stopRecordingAndRecognize(Language language);
  Future<void> cancelRecording();
  Future<void> dispose();
}
