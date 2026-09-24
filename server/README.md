# Santali Setu API backend

Node.js 20+ / Express 5 backend. Sarvam credentials exist only in the server environment. The Flutter app calls this service; it never calls Sarvam directly.

## Local setup

```bash
cd server
npm install
cp .env.example .env
```

Edit `.env` and set `SARVAM_API_KEY` from the Sarvam dashboard. Do not commit `.env`. Then run:

```bash
npm run dev
```

The backend listens on `0.0.0.0:${PORT:-3000}`. `GET /health` confirms service/key configuration without revealing the key.

## Provider wiring

- Speech: `POST https://api.sarvam.ai/speech-to-text`, multipart `file`, `language_code` (`hi-IN` or `sat-IN`), `model=saaras:v4`, `mode=transcribe`.
- Translation: `POST https://api.sarvam.ai/translate`, JSON `input`, `source_language_code`, `target_language_code`, `model=sarvam-translate:v1`, `mode=formal`.
- Authentication: `api-subscription-key` header, server-side only.

The mobile app sends a mono PCM16, 16 kHz WAV in `audio` to `POST /api/speech-to-text`; the backend checks it and forwards it to Sarvam as `file`. Audio requests are limited to 30 seconds and 10 MB. Translation accepts only the Hindi↔Santali language pair and up to 2,000 characters.

## Tests

```bash
npm test
```

These unit/route tests inject provider stubs and test validation, routing, fields, and error handling. They are not real AI tests.

For a real, non-mocked end-to-end provider run, set in `.env`:

```dotenv
SARVAM_HI_WAV=/absolute/path/to/hindi-16k-mono.wav
SARVAM_SAT_WAV=/absolute/path/to/santali-16k-mono.wav
```

Use genuine recordings, not generated speech. Santali audio should be provided by a fluent speaker. Then run:

```bash
npm run test:integration
```

This suite posts the files through the actual Express endpoints and invokes Sarvam Saaras and Sarvam Translate for both directions. It prints actual response strings. It skips if the key or either audio path is missing.

## Deploy

Deploy this folder as a Node 20+ web service. Configure `SARVAM_API_KEY` and `PORT` as provider environment secrets, bind/proxy HTTPS, and point Flutter's `API_BASE_URL` to the HTTPS origin. No Sarvam key is required or accepted by Flutter. The backend has no end-user authentication, so configure rate/usage limits at the hosting/provider layer before public exposure.
