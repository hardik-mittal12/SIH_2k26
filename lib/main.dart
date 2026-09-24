import 'package:flutter/material.dart';
import 'inference/model_manager.dart';
import 'inference/speech/platform_speech_engine.dart';
import 'inference/translation/platform_translation_engine.dart';
import 'presentation/translation_controller.dart';
import 'presentation/translation_screen.dart';
import 'services/permission_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final manager = ModelManager(
    translationEngine: PlatformTranslationEngine(),
    speechEngine: PlatformSpeechEngine(),
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
