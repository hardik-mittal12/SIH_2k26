# Santali Setu

A focused Android demo for **Hindi ↔ Santali speech translation**. Choose which language to speak, tap the microphone, and see the recognized speech and translation together. The app uses Sarvam Saaras v4 for speech recognition and Sarvam Translate v1 for translation; all provider calls and the Sarvam credential stay on the project backend.

> **Manual API check:** The Sarvam APIs and both `hi-IN` ↔ `sat-IN` directions have been manually verified for this demo. The automated live integration test is still optional and requires your own key and audio recordings.

## What you need

- Node.js 20 or later and npm
- Flutter and Android Studio/Android SDK
- A Sarvam API key
- An Android emulator, or an Android phone and a trusted shared Wi-Fi network

## 1. Clone and start the backend

```bash
git clone https://github.com/hardik-mittal12/SIH_2k26.git
cd SIH_2k26
cd server
npm install
cp .env.example .env
```

Open `server/.env` and put your Sarvam API key on the `SARVAM_API_KEY=` line. This is the **only required app/backend secret**. Keep the file on your machine; `.env` is ignored by Git. The backend uses port `3000` by default and needs no other settings for local development.

Start the backend:

```bash
npm run dev
```

Leave it running. In another terminal you can check that it is reachable:

```bash
curl http://127.0.0.1:3000/health
```

The health response indicates whether the server has a key configured; it never returns the key.

## 2. Run the Android app

From the repository root, in a second terminal:

```bash
cd SIH_2k26
flutter pub get
flutter run
```

The app is preconfigured to use `http://10.0.2.2:3000`, the Android emulator's route to the computer running the backend. No API URL command-line flags or Dart edits are needed for the emulator.

### Physical Android phone

1. Connect the phone and computer to the same trusted Wi-Fi network. Enable USB debugging and connect the phone, or use Android wireless debugging.
2. Find the computer's LAN IP address (for example, on macOS: `ipconfig getifaddr en0`; on Windows: `ipconfig`; on Linux: `ip addr`).
3. Keep the backend running. Allow inbound connections to port `3000` through the computer firewall if prompted.
4. Open **`lib/config/app_config.dart`** and change `backendBaseUrl` to `http://<COMPUTER-LAN-IP>:3000`. This is the single place to configure the app's backend address. Do not use `localhost` or `10.0.2.2` on a physical phone.
5. Run `flutter run` again with the phone selected.

The Android demo permits local HTTP so the emulator and a phone on a trusted LAN can reach the backend. For a deployed backend, set the same `backendBaseUrl` to its HTTPS address. Do not expose the local development server on a public or untrusted network.

## Using the app

1. Check the direction card: **Speak in** and **Translate to** show the current languages. Tap the swap icon to reverse them.
2. Tap the large microphone and allow microphone permission. Speak clearly, then tap stop.
3. Santali Setu uploads the WAV recording. The backend sends it to Saaras v4 in the selected language, passes the transcript to Sarvam Translate v1, and returns both texts.
4. Read the recognized speech and translation. Use the copy icon to copy the result, or the clear icon to start over.

Hindi speech uses `hi-IN` and translates `hi-IN → sat-IN`. Santali speech uses `sat-IN` and translates `sat-IN → hi-IN`. Audio is recorded as mono PCM16 16 kHz WAV and requests are limited to 30 seconds.

## Backend endpoints

- `GET /health` — backend status and model names; never returns credentials.
- `POST /api/voice-translate` — multipart fields `audio` (WAV) and `language` (`hi-IN` or `sat-IN`). Runs speech recognition and translation on the backend, returning `transcript` and `translatedText` together, plus the selected source/target codes.
- `POST /api/speech-to-text` — speech-only endpoint with the same multipart fields.
- `POST /api/translate` — JSON `{ "text": "...", "sourceLanguage": "hi-IN", "targetLanguage": "sat-IN" }`; only Hindi ↔ Santali is accepted.

The backend validates audio type, WAV structure, sample format, duration, and size; it caps text at 2,000 Unicode code points. Responses use clear sanitized errors, provider calls have timeouts, non-credentialed CORS preflight is supported, and API routes are rate-limited per IP. Native Flutter does not rely on browser CORS.

## Release APK

Ensure `backendBaseUrl` in `lib/config/app_config.dart` points to the backend the demo phone can reach, then run from the repository root:

```bash
flutter build apk --release
```

APK location:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For a demo install, copy the APK to the phone or run `adb install -r build/app/outputs/flutter-apk/app-release.apk`. This project signs the demo release with the generated debug signing key so the command works without extra setup. A Play Store/public production release must use a privately managed release keystore and an HTTPS backend.

## Tests

Backend unit and route tests (provider calls are isolated test stubs, not live Sarvam results):

```bash
cd server
npm test
```

The real-provider test sends genuine audio to the backend and Sarvam in both directions. It makes billable external requests; use your own licensed 16 kHz mono PCM WAV files (30 seconds or shorter):

```bash
cd server
SARVAM_HI_WAV=/absolute/path/hindi.wav \
SARVAM_SAT_WAV=/absolute/path/santali.wav \
npm run test:integration
```

The test uses `SARVAM_API_KEY` from `server/.env`. No test audio is fabricated or bundled.

Flutter/Android checks, when the SDKs are installed:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

## Project notes

- Production Flutter wiring uses only the Sarvam backend adapters. The mock adapters are retained solely for the widget test and cannot generate translation output.
- No offline IndicConformer or IndicTrans2 model is included or used.
- The demo backend has no end-user authentication or usage quota. Use provider and host-side rate/usage limits before public deployment.
- Never add a Sarvam key to Flutter/Dart, Android resources, Gradle files, APKs, or source control.
