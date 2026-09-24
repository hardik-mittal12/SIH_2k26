# Santali Setu — SIH 2026 API-backed prototype

Flutter Android client for bidirectional Hindi ↔ Santali speech translation. The app records locally and sends the recording to this project's backend. The backend alone holds the Sarvam API key and calls Sarvam Saaras for transcription, then Sarvam Translate for translation. **Inference is cloud/API-based in this version; offline operation is not supported.** No production code returns mock AI output.

## Verified Sarvam API configuration

Based on Sarvam's current API documentation:

- Speech endpoint: `POST https://api.sarvam.ai/speech-to-text`, multipart field `file`, `mode=transcribe`, `model=saaras:v4`. `saaras:v4` is currently documented as the latest model; `saaras:v3` is also supported. The docs list Hindi `hi-IN` and Santali `sat-IN` for transcription. The endpoint accepts WAV and works best at 16 kHz; Saaras REST is documented for audio up to 30 seconds. [STT endpoint](https://docs.sarvam.ai/api-reference/speech-to-text/transcribe) · [Saaras model guide](https://docs.sarvam.ai/api/getting-started/models/saaras)
- Translation endpoint: `POST https://api.sarvam.ai/translate`, model `sarvam-translate:v1`, formal mode. The current language list includes Hindi `hi-IN` and Santali `sat-IN`; the documented text limit for this model is 2,000 characters. [Translation endpoint](https://docs.sarvam.ai/api-reference/text/translate-text)
- Sarvam authentication is sent by the backend as the `api-subscription-key` header. The key is never compiled into Flutter.

The selected model IDs are `saaras:v4` and `sarvam-translate:v1`. Saaras v4 is used with explicit `language_code=hi-IN` or `sat-IN`. Translation sends `source_language_code` and `target_language_code` in the selected direction.

## Clone and start the backend

Requirements: Node.js 20 or later.

```bash
git clone https://github.com/hardik-mittal12/SIH_2k26.git
cd SIH_2k26/server
npm install
cp .env.example .env
```

Open `server/.env` and put your Sarvam key on the `SARVAM_API_KEY` line:

```dotenv
SARVAM_API_KEY=paste_your_key_here
PORT=3000
```

Get the key from your Sarvam dashboard. Keep it only in `server/.env`; the repository ignores this file. Never paste the key into Flutter, `--dart-define`, a screenshot, or a checked-in file.

Start the development server:

```bash
npm run dev
```

The server binds to `0.0.0.0:3000`. Confirm it is running from another terminal:

```bash
curl http://127.0.0.1:3000/health
```

The response includes `sarvamConfigured: true` when the key is present; it does not expose the key. API routes return useful sanitized errors if the key is missing or Sarvam is unavailable.

## Run Flutter

From the repository root, in a second terminal:

```bash
cd ..
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's special route to the development host machine. The API address has no default or hardcoded localhost fallback; it must be supplied with `API_BASE_URL`.

### Physical Android phone

1. Connect the phone and development Mac to the same trusted Wi-Fi network; enable USB debugging and connect the phone, or use wireless debugging.
2. Find the Mac's LAN address, for example `ipconfig getifaddr en0` (Wi-Fi; use the active interface if it differs).
3. Keep the backend running; it binds to `0.0.0.0`. Allow incoming connections to port 3000 in the Mac firewall if prompted.
4. Run Flutter using the Mac's LAN IP, not `localhost` and not `10.0.2.2`:

```bash
flutter devices
flutter run -d <phone-device-id> \\
  --dart-define=API_BASE_URL=http://<MAC-LAN-IP>:3000
```

For example, replace `<MAC-LAN-IP>` with the address printed by `ipconfig getifaddr en0`. Debug builds permit cleartext HTTP for emulator/LAN development only. **Use an HTTPS URL for release builds and deployed demos.** Do not expose the development server or Sarvam key on an untrusted public network.

## Endpoints

### `POST /api/speech-to-text`

`multipart/form-data`: `audio=<WAV file>`, `language=hi-IN|sat-IN`. The app's Android recorder supplies mono PCM16 WAV at 16 kHz. The backend validates WAV headers, format, non-empty audio, 10 MB maximum, and the Saaras 30-second request limit before forwarding it to Sarvam as multipart field `file`.

Response:

```json
{"success":true,"text":"<Sarvam transcript>","language":"hi-IN","requestId":"..."}
```

### `POST /api/translate`

JSON request:

```json
{"text":"नमस्ते","sourceLanguage":"hi-IN","targetLanguage":"sat-IN"}
```

The reverse direction is `sourceLanguage=sat-IN`, `targetLanguage=hi-IN`.

Response:

```json
{"success":true,"translatedText":"<Sarvam translation>","requestId":"..."}
```

`GET /health` reports backend configuration only. There is no inference endpoint other than the two Sarvam-backed routes; no local model or mock fallback is active.

## Pipeline and errors

Hindi → Santali: native microphone → 16 kHz mono PCM16 WAV → backend `/api/speech-to-text` with `hi-IN` → transcript shown in the source field → backend `/api/translate` with `hi-IN` → `sat-IN` → translation shown in the result.

Santali → Hindi uses the swapped direction and `sat-IN` for transcription. The UI exposes recording, uploading, transcribing, and translating progress, blocks concurrent actions, and displays backend/network/provider errors without stack traces. Microphone permission is requested on Android when recording starts.

Sarvam REST speech requests are limited to 30 seconds here. Longer recordings are rejected by the app/backend; the application does not silently truncate them. Translation text is limited to 2,000 Unicode code points.

## Tests

Unit/route tests use isolated provider stubs and do **not** claim a real Sarvam response:

```bash
cd server
npm test
```

The separate integration test makes real requests through the backend to Sarvam and is not mocked. It requires a valid `SARVAM_API_KEY` in `server/.env` and two real, licensed 16 kHz mono PCM WAV files no longer than 30 seconds. Set `SARVAM_HI_WAV` and `SARVAM_SAT_WAV` in `server/.env`, then run:

```bash
npm run test:integration
```

The test prints the actual Hindi transcript, Hindi→Santali translation, Santali transcript, and Santali→Hindi translation. It is skipped when credentials or samples are absent. This checkout has no Sarvam key or audio fixtures, so **real provider tests and actual sample outputs were not run here**.

To prepare audio samples on a Mac from your own recordings (with FFmpeg installed):

```bash
ffmpeg -i my_hindi_recording.m4a -ac 1 -ar 16000 -sample_fmt s16 -t 30 server/hindi_16k.wav
ffmpeg -i my_santali_recording.m4a -ac 1 -ar 16000 -sample_fmt s16 -t 30 server/santali_16k.wav
```

Use a native Santali speaker for the Santali sample. Add those paths as `SARVAM_HI_WAV` and `SARVAM_SAT_WAV` in the ignored `server/.env`.

Flutter checks and Android build:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release \\
  --dart-define=API_BASE_URL=https://<your-backend-host>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

This execution environment has no Flutter/Dart, Java, Android SDK, emulator, or physical phone, so these commands and microphone capture could not be tested here.

## Deployment notes

Deploy `server/` as a Node 20+ web service on a simple Node-capable host. Set `SARVAM_API_KEY` and `PORT` in that host's secret/environment settings, expose the assigned HTTPS URL, then build Flutter with `--dart-define=API_BASE_URL=https://<your-backend-host>`. Do not enable HTTP/cleartext for a production build. The Sarvam key remains only in the server environment. Configure provider usage limits and hosting-level rate limits before public deployment; this demo backend does not implement user authentication.

## Project status

The API-backed production path is implemented; Node backend unit and route tests can run locally. Real Sarvam calls require the user's server-side API key and real audio samples. No real provider result, physical Android test, Flutter test, or APK build is claimed in this environment.
