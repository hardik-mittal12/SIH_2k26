import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../domain/language.dart';
import 'speech_engine.dart';

/// Android platform adapter for native PCM recording and model-backed ASR.
/// It intentionally fails closed if the native runtime/checkpoint is missing.
class PlatformSpeechEngine implements SpeechEngine {
  static const _channel = MethodChannel('org.sih.santali_setu/inference');
  final Set<Language> _available = {};
  Language? _recordingLanguage;

  String _code(Language language) => language == Language.hindi ? 'hi' : 'sat';

  @override
  Future<void> initialize(Language language) async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'initializeSpeech',
        {'language': _code(language)},
      );
      if (status?['available'] == true) {
        _available.add(language);
      } else {
        _available.remove(language);
      }
    } on PlatformException catch (error) {
      _available.remove(language);
      throw StateError(error.message ?? 'Speech model initialization failed.');
    } on MissingPluginException {
      _available.remove(language);
      throw StateError('Native Android speech inference is not installed.');
    }
  }

  @override
  bool isAvailable(Language language) => _available.contains(language);

  @override
  Future<void> startRecording(Language language) async {
    if (_recordingLanguage != null) {
      throw StateError('A recording is already active. Stop it before starting another.');
    }
    try {
      await _channel.invokeMethod<void>('startRecording', {
        'language': _code(language),
      });
      _recordingLanguage = language;
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Could not start microphone recording.');
    } on MissingPluginException {
      throw StateError('Android microphone recording is unavailable on this platform.');
    }
  }

  @override
  Future<String> stopRecordingAndRecognize(Language language) async {
    if (_recordingLanguage != language) {
      throw StateError('No active ${language.label} recording.');
    }
    _recordingLanguage = null;
    try {
      final audio = await _channel.invokeMethod<Uint8List>('stopRecording');
      if (audio == null || audio.length <= 44) {
        throw StateError('The recording was empty. Speak for longer and try again.');
      }
      return await _channel.invokeMethod<String>('recognize', {
            'language': _code(language),
            'wav': audio,
          }) ??
          '';
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Speech recognition failed.');
    } on MissingPluginException {
      throw StateError('Native IndicConformer inference is unavailable.');
    }
  }

  @override
  Future<void> cancelRecording() async {
    if (_recordingLanguage == null) return;
    _recordingLanguage = null;
    try {
      await _channel.invokeMethod<void>('cancelRecording');
    } on PlatformException {
      // Best-effort release during cancellation/disposal.
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
