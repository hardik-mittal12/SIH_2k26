import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:santali_setu/domain/language.dart';
import 'package:santali_setu/inference/model_manager.dart';
import 'package:santali_setu/inference/speech/mock_speech_engine.dart';
import 'package:santali_setu/inference/speech/speech_to_text_engine.dart';
import 'package:santali_setu/inference/translation/mock_translation_engine.dart';
import 'package:santali_setu/main.dart';
import 'package:santali_setu/presentation/translation_controller.dart';
import 'package:santali_setu/services/permission_service.dart';

class _NoSpeechNetwork implements SpeechToTextEngine {
  @override
  Future<SpeechRecognitionResult> transcribe({
    required Uint8List wavAudio,
    required Language language,
    void Function(bool uploadFinished)? onUploadFinished,
  }) => throw UnsupportedError('This widget test never sends real audio.');
}

void main() {
  testWidgets('shows the bidirectional translation shell', (tester) async {
    final controller = TranslationController(
      ModelManager(
        translationEngine: MockTranslationEngine(),
        speechEngine: MockSpeechEngine(),
        speechToTextEngine: _NoSpeechNetwork(),
      ),
      MicrophonePermissionService(),
    );

    await tester.pumpWidget(SantaliSetuApp(controller: controller));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Santali Setu'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('Santali'), findsOneWidget);
  });
}
