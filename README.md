# Santali Setu — SIH 2026 prototype

Flutter Android prototype for Hindi ↔ Santali translation. This repository currently contains Android microphone-capture code and explicit Flutter-to-Android inference contracts, **but it does not yet contain or run either AI model**. Since ASR reports unavailable, the current UI correctly blocks recording rather than collecting audio that it cannot transcribe. The production app is wired to platform adapters that fail closed; it does not use the test fakes and does not present fabricated recognition or translation as real output.

## Repository and toolchain

- Flutter application (`pubspec.yaml`, stable project metadata).
- `pubspec.yaml` declares Dart `>=3.3.0 <4.0.0`; the checked-in `pubspec.lock` was resolved with Dart `>=3.10.0` / Flutter `>=3.18.0-18.0.pre.54`. Use a current stable Flutter SDK and run `flutter pub get` to resolve for that SDK.
- Android Java/Kotlin target: 17. NDK: `28.1.13356709`.
- `minSdk` and `targetSdk` inherit the selected Flutter SDK defaults; they are not pinned in this repository.
- Runtime pub dependencies: Flutter SDK only. There is no Dart recorder, ONNX, TFLite, or model download dependency.
- Android declares `RECORD_AUDIO`. The native recorder requests mono PCM16 at 16 kHz and wraps captured samples in a WAV container.

## Model support and access status

### Speech recognition

Requested checkpoint: [`ai4bharat/indic-conformer-600m-multilingual`](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual).

AI4Bharat's model card lists Hindi (`hi`) and Santali (`sat`) among its 22 supported languages, and documents CTC/RNNT decoding over 16 kHz audio. The checkpoint has 600 million parameters. Hugging Face currently gates its files behind acceptance of the repository's conditions/contact-information sharing. This environment did not have accepted access or the weights, so no download, load, or inference test is claimed here. The checkpoint is an ASR model distributed for the Transformers/NeMo ecosystem; this project has not verified a production-ready conversion/runtime for Android.

### Translation

Smallest official bidirectional Indic-Indic checkpoint selected for evaluation: [`ai4bharat/indictrans2-indic-indic-dist-320M`](https://huggingface.co/ai4bharat/indictrans2-indic-indic-dist-320M), 0.3 billion parameters per its model card. The language tags are `hin_Deva` and `sat_Olck`. The model card demonstrates the IndicTrans2 Transformers + IndicTransToolkit path. Its Hugging Face files are also gated. No checkpoint was downloaded or independently tested in this checkout. The model's parameter count is known; actual on-disk size for an accessible downloaded revision was not measured.

`tooling/export_indictrans2_onnx.py`, `tooling/build_indictrans2_tokenizer_onnx.py`, and `tooling/validate_onnx_forward_parity.py` are exploratory export/parity tooling only. They do not produce checked-in models, do not integrate an Android inference runtime, and do not establish that an exported graph can run correctly or efficiently on ARM64 Android. Do not treat their presence as successful mobile conversion.

## Current implementation

1. `MainActivity.kt` implements Android `AudioRecord` capture with mono signed PCM16 at 16 kHz and WAV packaging. Runtime permission is requested. The current UI cannot reach that capture because the native initialization reports IndicConformer unavailable.
2. `PlatformSpeechEngine` and `PlatformTranslationEngine` call the `org.sih.santali_setu/inference` MethodChannel. Language IDs are explicit: ASR `hi` / `sat`; translation `hin_Deva` / `sat_Olck`.
3. The Android bridge currently reports the two model runtimes as unavailable and refuses recognition/translation. The Flutter UI displays this condition. The methods do not return sample text.
4. The intended completion requires a validated ARM64 inference implementation and weights. IndicConformer is 600M parameters and IndicTrans2 distilled is 320M parameters; both model memory, conversion compatibility, latency, package size, and quality must be measured on actual target devices before choosing a native runtime or claiming offline readiness.

## Run and verify the current code

From the repository root, with Flutter installed:

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run -d <android-device-id>
```

The app should visibly report that model inference is unavailable. Do not expect the microphone button to yield transcription until the native ASR runtime and model are supplied. There are no model-independent expected transcription/translation outputs to report.

Build a debug or release APK:

```bash
flutter build apk --debug
flutter build apk --release
```

APK output is normally `build/app/outputs/flutter-apk/app-debug.apk` or `app-release.apk`. Build has not been verified in this environment because Flutter, Java, Android SDK/NDK, and the Gradle wrapper are unavailable here.

## Tests not performed / release blockers

- No IndicConformer or IndicTrans2 files downloaded, loaded, or run; no real audio test samples or transcriptions/translations are available.
- No end-to-end Hindi/Santali, noise, slow-speech, or conversational test, and no latency numbers. Reporting invented values would be misleading.
- No validated mobile conversion/runtime, native model loader, JNI/FFI implementation, tokenizer deployment, model packaging/download manager, or APK/AAB size measurement.
- No Flutter static analysis, widget tests, Android build, or physical-device recording test could be run in the current tool environment (Flutter/Dart, Java, and Android toolchain are absent).
- Model-card language support is not a guarantee of Santali recognition/translation quality. Santali output should be reviewed by fluent speakers and evaluated on held-out speech/text before production.

The application is therefore a **non-mocked integration scaffold with a PCM capture implementation that has not been verified on a device**, not a finished AI translation prototype. It must not be presented as offline IndicConformer/IndicTrans2 inference until the blockers above are closed.
