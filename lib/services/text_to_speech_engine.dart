import '../domain/language.dart';

abstract class TextToSpeechEngine {
  Future<void> speak(String text, Language language);
  Future<void> stop();
}
