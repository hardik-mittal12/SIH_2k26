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

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B4A),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Santali Setu',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: TranslationScreen(controller: controller),
      );
}
