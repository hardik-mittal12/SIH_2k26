# Santali Setu backend

Node 20+ / Express backend used by the Android demo. The Sarvam key is read only from `server/.env`; the Flutter client never sends or stores it.

## Local setup

From the repository root:

```bash
cd server
npm install
cp .env.example .env
```

Set `SARVAM_API_KEY` in the local `.env`, then start the server:

```bash
npm run dev
```

The backend defaults to port `3000`, binds to `0.0.0.0` for emulator/phone access, and loads `.env` automatically. No other local environment configuration is required. `GET /health` reports status and model IDs without exposing credentials.

## API flow

- `POST /api/voice-translate`: `multipart/form-data` containing `audio` (mono 16 kHz PCM16 WAV) and `language` (`hi-IN` or `sat-IN`). Calls Saaras v4, then Sarvam Translate v1 in the matching reverse language direction; responds with both `transcript` and `translatedText`.
- `POST /api/speech-to-text`: standalone Saaras v4 transcription endpoint with the same multipart fields.
- `POST /api/translate`: JSON `{ text, sourceLanguage, targetLanguage }`, using Sarvam Translate v1. Only Hindi ↔ Santali pairs are accepted.

Provider calls use the server-only `api-subscription-key` header and request timeouts. WAV format, duration (30 seconds), and upload size (10 MB) are validated. Translation input is capped at 2,000 Unicode code points. Errors returned to the app are sanitized. Non-credentialed CORS preflight is enabled; the native Android client itself does not require CORS. API routes have a built-in per-IP limit of 30 requests per minute; configure additional host/provider quotas before public deployment.

## Tests

```bash
npm test
```

Unit/route tests inject stubs for deterministic validation; they are not live provider calls.

For a real, billable end-to-end provider run, provide your own licensed 16 kHz mono PCM WAV recordings, 30 seconds or shorter:

```bash
SARVAM_HI_WAV=/absolute/path/hindi.wav \
SARVAM_SAT_WAV=/absolute/path/santali.wav \
npm run test:integration
```

The test reads `SARVAM_API_KEY` from `.env`, calls both real voice-translation directions, and prints the actual transcript and translation responses. No sample audio is included in this repository.

## Deployment

Deploy this folder as a Node 20+ service. Configure only `SARVAM_API_KEY` as a server secret; the host-provided `PORT` is honored, defaulting to `3000`. Put the service behind HTTPS for deployed demos and change `backendBaseUrl` in `lib/config/app_config.dart` to that HTTPS origin. The demo has no end-user authentication; set provider/hosting usage and rate limits before public exposure.
