import 'package:flutter_test/flutter_test.dart';
import 'package:santali_setu/inference/model_manager.dart';
import 'package:santali_setu/inference/speech/mock_speech_engine.dart';
import 'package:santali_setu/inference/translation/mock_translation_engine.dart';
import 'package:santali_setu/main.dart';
import 'package:santali_setu/presentation/translation_controller.dart';
import 'package:santali_setu/services/permission_service.dart';

void main() {
  testWidgets('shows the bidirectional translation shell', (tester) async {
    final controller = TranslationController(
      ModelManager(
        translationEngine: MockTranslationEngine(),
        speechEngine: MockSpeechEngine(),
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
