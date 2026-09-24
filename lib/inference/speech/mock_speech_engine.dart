import '../../domain/language.dart';
import 'speech_engine.dart';

/// Test-only fake. It is never wired into the production application.
class MockSpeechEngine implements SpeechEngine {
  final Set<Language> _ready = {};
  Language? _recording;

  @override
  Future<void> initialize(Language language) async {
    _ready.add(language);
  }

  @override
  bool isAvailable(Language language) => _ready.contains(language);

  @override
  Future<void> startRecording(Language language) async {
    if (!isAvailable(language)) throw StateError('Speech test engine is not initialized.');
    _recording = language;
  }

  @override
  Future<String> stopRecordingAndRecognize(Language language) async {
    if (_recording != language) throw StateError('No active test recording.');
    _recording = null;
    throw UnsupportedError('MockSpeechEngine does not synthesize transcription output.');
  }

  @override
  Future<void> cancelRecording() async {
    _recording = null;
  }

  @override
  Future<void> dispose() async {
    _recording = null;
    _ready.clear();
  }
}
