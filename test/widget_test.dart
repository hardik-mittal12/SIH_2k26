import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santali_setu/domain/language.dart';
import 'package:santali_setu/inference/model_manager.dart';
import 'package:santali_setu/inference/speech/speech_engine.dart';
import 'package:santali_setu/inference/speech/speech_to_text_engine.dart';
import 'package:santali_setu/main.dart';
import 'package:santali_setu/presentation/translation_controller.dart';
import 'package:santali_setu/services/permission_service.dart';

import 'support/mock_speech_engine.dart';
import 'support/mock_translation_engine.dart';

class _NoSpeechNetwork implements SpeechToTextEngine {
  @override
  Future<SpeechRecognitionResult> transcribe({
    required Uint8List wavAudio,
    required Language language,
    void Function(bool uploadFinished)? onUploadFinished,
  }) => throw UnsupportedError('This widget test never sends real audio.');
}

class _WidgetAudioRecorder implements SpeechEngine {
  final Set<Language> _initialized = {};
  Language? _recording;

  @override
  Future<void> initialize(Language language) async {
    _initialized.add(language);
  }

  @override
  bool isAvailable(Language language) => _initialized.contains(language);

  @override
  Future<void> startRecording(Language language) async {
    _recording = language;
  }

  @override
  Future<Uint8List> stopRecording(Language language) async {
    _recording = null;
    return Uint8List(64);
  }

  @override
  Future<void> cancelRecording() async {
    _recording = null;
  }

  @override
  Future<void> dispose() async {
    _recording = null;
    _initialized.clear();
  }
}

class _WidgetVoiceTranslation implements SpeechToTextEngine, VoiceTranslationEngine {
  final List<Language> spokenLanguages = [];

  @override
  Future<SpeechRecognitionResult> transcribe({
    required Uint8List wavAudio,
    required Language language,
    void Function(bool uploadFinished)? onUploadFinished,
  }) => throw UnsupportedError('The widget flow uses the combined translation endpoint.');

  @override
  Future<VoiceTranslationResult> translateSpeech({
    required Uint8List wavAudio,
    required Language source,
    required Language target,
    void Function(bool uploadFinished)? onUploadFinished,
  }) async {
    spokenLanguages.add(source);
    onUploadFinished?.call(false);
    onUploadFinished?.call(true);
    return VoiceTranslationResult(
      transcript: source == Language.hindi ? 'नमस्ते' : 'ᱡᱚᱦᱟᱨ',
      translatedText: source == Language.hindi ? 'ᱡᱚᱦᱟᱨ' : 'नमस्कार',
      languageCode: source.sarvamCode,
      elapsed: const Duration(milliseconds: 240),
    );
  }
}

void main() {
  testWidgets('shows the first-use speech translation experience', (tester) async {
    final controller = TranslationController(
      ModelManager(
        translationEngine: MockTranslationEngine(),
        speechEngine: MockSpeechEngine(),
        speechToTextEngine: _NoSpeechNetwork(),
      ),
      MicrophonePermissionService(),
    );

    await tester.pumpWidget(SantaliSetuApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Santali Setu'), findsOneWidget);
    expect(find.text('Hindi ↔ Santali speech translation'), findsOneWidget);
    expect(find.text('SPEAK IN'), findsOneWidget);
    expect(find.text('TRANSLATE TO'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('Santali'), findsOneWidget);
    expect(find.text('Tap to speak'), findsOneWidget);
    expect(find.text('Your words will appear here'), findsOneWidget);
    expect(find.text('Your translation will appear here.'), findsOneWidget);
    expect(find.byTooltip('Copy translation'), findsOneWidget);
  });

  testWidgets('swap changes the displayed translation direction', (tester) async {
    final controller = TranslationController(
      ModelManager(
        translationEngine: MockTranslationEngine(),
        speechEngine: MockSpeechEngine(),
        speechToTextEngine: _NoSpeechNetwork(),
      ),
      MicrophonePermissionService(),
    );

    await tester.pumpWidget(SantaliSetuApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Swap languages'));
    await tester.pumpAndSettle();

    final languageLabels =
        tester.widgetList<Text>(find.byType(Text)).map((e) => e.data).toList();
    expect(languageLabels.indexOf('Santali'), lessThan(languageLabels.indexOf('Hindi')));
  });

  testWidgets('records and displays both directions from the combined voice flow',
      (tester) async {
    const permissionChannel = MethodChannel('org.sih.santali_setu/permissions');
    permissionChannel.setMockMethodCallHandler((_) async => true);
    addTearDown(() => permissionChannel.setMockMethodCallHandler(null));

    final voiceEngine = _WidgetVoiceTranslation();
    final controller = TranslationController(
      ModelManager(
        translationEngine: MockTranslationEngine(),
        speechEngine: _WidgetAudioRecorder(),
        speechToTextEngine: voiceEngine,
      ),
      MicrophonePermissionService(),
    );

    await tester.pumpWidget(SantaliSetuApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Start recording in Hindi'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Listening…'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Stop recording'));
    await tester.pumpAndSettle();
    expect(find.text('नमस्ते'), findsOneWidget);
    expect(find.text('ᱡᱚᱦᱟᱨ'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear conversation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Swap languages'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Start recording in Santali'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.bySemanticsLabel('Stop recording'));
    await tester.pumpAndSettle();

    expect(find.text('ᱡᱚᱦᱟᱨ'), findsOneWidget);
    expect(find.text('नमस्कार'), findsOneWidget);
    expect(voiceEngine.spokenLanguages, [Language.hindi, Language.santali]);
  });
}
