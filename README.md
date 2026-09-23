# Santali Setu

An offline-first Flutter demonstration shell for bidirectional Hindi ↔ Santali translation. It deliberately ships with **development mock** inference only: no output is presented as a real translation.

## Run

```bash
flutter pub get
flutter run
```

## IndicTrans2 local smoke test

The downloaded IndicTrans2 model is tested with the Python environment at
`/Users/hardikmittal/models/indictrans-test`. Its toolkit requires a recent
Transformers release, and this custom model must run with generation caching
disabled for compatibility:

```bash
/Users/hardikmittal/models/indictrans-test/bin/pip install --upgrade \
  'transformers>=4.51,<5'
/Users/hardikmittal/models/indictrans-test/bin/python \
  /Users/hardikmittal/models/test_indictrans.py
```

The smoke test currently translates Hindi `आप कैसे हैं?` to Santali and
should produce `ᱟᱢ ᱪᱮᱫ ᱞᱮᱠᱟ?`. The Flutter app still uses its development mock
adapter; IndicTrans2 is not loaded into the mobile APK automatically because
the Python Hugging Face runtime and 2.4 GB model directory are not Android
assets.

The app requires no network permission. Android microphone permission is requested only when voice input is started.

## Model integration

Put model assets under `assets/models/` (or package them in Android `src/main/assets/` when a native runtime needs file paths). Replace the factories in `lib/main.dart`:

```dart
translationEngineFactory: () => TfliteTranslationEngine(...),
speechEngineFactory: () => NativeSpeechEngine(...),
```

Implement the contracts in `lib/inference/translation/translation_engine.dart` and `lib/inference/speech/speech_engine.dart`. `ModelManager` owns initialization, warm-up, reuse, timings, failures, and disposal. It deliberately does not reload models per translation.

### Translation adapter checklist

1. Load model, tokenizer, vocabulary, and config in `initialize`.
2. Preprocess source text according to `sourceLanguage` and `targetLanguage`.
3. Keep interpreter/session/native handle resident; preallocate tensors where supported.
4. Run inference off the Flutter UI thread (native worker, FFI, or isolate appropriate to the runtime).
5. Decode output tokens and return `TranslationResult` with measured stage timings.
6. Invoke one warm-up inference in `warmUp`.
7. Route both directions inside one engine if the model supports it, otherwise select the proper per-direction model.

### Android bridge

`android/app/src/main/kotlin/.../MainActivity.kt` contains an intentionally small `MethodChannel` placeholder named `org.sih.santali_setu/inference`. A production adapter may call native `initialize`, `translate`, `recognize`, and `dispose` methods through that channel, or use FFI for a C/C++ runtime. Keep all model code outside widgets.

### Performance and size

Use the in-app developer panel to benchmark real model adapters: min, average, max, and P95 are derived from measured wall-clock durations. Profile with Flutter DevTools and Android Studio CPU/Memory profilers on a release build. To approach a 2 GB package later, prefer quantized models, ABI splits/App Bundles, compressed vocabularies, shared multilingual encoders, and on-demand optional model packs; measure accuracy and latency after every compression change.
# SIH_2k26
