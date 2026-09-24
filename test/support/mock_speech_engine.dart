import 'dart:typed_data';

import 'package:santali_setu/domain/language.dart';
import 'package:santali_setu/inference/speech/speech_engine.dart';

/// Test-only recorder stub. It never produces synthetic audio or a transcript.
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
    if (!isAvailable(language)) throw StateError('Test recorder is not initialized.');
    _recording = language;
  }

  @override
  Future<Uint8List> stopRecording(Language language) async {
    if (_recording != language) throw StateError('No active test recording.');
    _recording = null;
    throw UnsupportedError('Test recorder does not create audio data.');
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
