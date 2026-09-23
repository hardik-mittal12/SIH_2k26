import '../../domain/language.dart';

abstract class SpeechEngine {
  Future<void> initialize(Language language);
  Future<String> recognize({required Language language});
  Future<void> stop();
  Future<void> dispose();
  bool isAvailable(Language language);
}
