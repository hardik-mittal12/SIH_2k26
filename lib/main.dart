import 'package:flutter/material.dart';

import 'inference/model_manager.dart';
import 'inference/speech/android_audio_recorder.dart';
import 'inference/speech/sarvam_speech_to_text_engine.dart';
import 'inference/translation/sarvam_translation_engine.dart';
import 'presentation/translation_controller.dart';
import 'presentation/translation_screen.dart';
import 'services/permission_service.dart';
import 'services/sarvam_backend_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = SarvamBackendClient();
  final manager = ModelManager(
    translationEngine: SarvamTranslationEngine(backend),
    speechEngine: AndroidAudioRecorder(),
    speechToTextEngine: SarvamSpeechToTextEngine(backend),
  );
  runApp(
    SantaliSetuApp(
      controller: TranslationController(manager, MicrophonePermissionService()),
    ),
  );
}

class SantaliSetuApp extends StatelessWidget {
  const SantaliSetuApp({super.key, required this.controller});
  final TranslationController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Santali Setu',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: TranslationScreen(controller: controller),
      );
}
