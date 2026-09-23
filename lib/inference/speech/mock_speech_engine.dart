import '../../domain/language.dart';
import 'speech_engine.dart';

/// Development-only local stand-in; no audio is uploaded or recognised.
class MockSpeechEngine implements SpeechEngine {
  final Set<Language> _ready = {};
  bool _stopped = false;
  @override
  Future<void> initialize(Language language) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));
    _ready.add(language);
  }

  @override
  bool isAvailable(Language language) => _ready.contains(language);
  @override
  Future<String> recognize({required Language language}) async {
    if (!isAvailable(language)) {
      throw StateError('Speech model unavailable for ${language.label}.');
    }
    _stopped = false;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_stopped) throw StateError('Speech recognition cancelled.');
    return language == Language.hindi
        ? 'नमस्ते, यह विकास के लिए मॉक वॉइस इनपुट है।'
        : '[DEVELOPMENT MOCK Santali speech input]';
  }

  @override
  Future<void> stop() async => _stopped = true;
  @override
  Future<void> dispose() async => _ready.clear();
}
