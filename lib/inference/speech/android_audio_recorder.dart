import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../domain/language.dart';
import 'speech_engine.dart';

/// Android microphone bridge. Speech decoding is intentionally not performed here.
class AndroidAudioRecorder implements SpeechEngine {
  static const _channel = MethodChannel('org.sih.santali_setu/audio');
  final Set<Language> _available = {};
  Language? _recordingLanguage;

  @override
  Future<void> initialize(Language language) async {
    // AudioRecord is language-independent; the selected locale is sent to the backend later.
    _available.add(language);
  }

  @override
  bool isAvailable(Language language) => _available.contains(language);

  @override
  Future<void> startRecording(Language language) async {
    if (!isAvailable(language)) {
      throw StateError('Microphone capture is unavailable for ${language.label}.');
    }
    if (_recordingLanguage != null) {
      throw StateError('A recording is already active. Stop it before starting another.');
    }
    try {
      await _channel.invokeMethod<void>('startRecording', {
        'language': language.sarvamCode,
      });
      _recordingLanguage = language;
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Could not start microphone recording.');
    } on MissingPluginException {
      throw StateError('Android microphone recording is unavailable on this platform.');
    }
  }

  @override
  Future<Uint8List> stopRecording(Language language) async {
    if (_recordingLanguage != language) {
      throw StateError('No active ${language.label} recording.');
    }
    _recordingLanguage = null;
    try {
      final audio = await _channel.invokeMethod<Uint8List>('stopRecording');
      if (audio == null || audio.length <= 44) {
        throw StateError('The recording was empty. Speak for longer and try again.');
      }
      return audio;
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Could not finish microphone recording.');
    } on MissingPluginException {
      throw StateError('Android microphone recording is unavailable on this platform.');
    }
  }

  @override
  Future<void> cancelRecording() async {
    if (_recordingLanguage == null) return;
    _recordingLanguage = null;
    try {
      await _channel.invokeMethod<void>('cancelRecording');
    } on PlatformException {
      // Best-effort recorder release during cancellation/disposal.
    } on MissingPluginException {
      // No native recorder exists on this platform.
    }
  }

  @override
  Future<void> dispose() async {
    await cancelRecording();
    _available.clear();
  }
}
