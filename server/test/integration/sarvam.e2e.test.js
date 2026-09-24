import 'dotenv/config';
import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createApp } from '../../src/app.js';

const hindiAudio = process.env.SARVAM_HI_WAV;
const santaliAudio = process.env.SARVAM_SAT_WAV;
const skipReason = !process.env.SARVAM_API_KEY
  ? 'Set SARVAM_API_KEY in server/.env to run real provider integration tests.'
  : !hindiAudio || !santaliAudio
    ? 'Set SARVAM_HI_WAV and SARVAM_SAT_WAV to real licensed 16 kHz mono PCM WAV samples.'
    : false;

test('real Hindi ↔ Santali voice translation calls Saaras v4 and Sarvam Translate v1', {
  skip: skipReason,
  timeout: 240_000,
}, async () => {
  const server = createServer(createApp());
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const translateSample = async (path, language, targetLanguage) => {
    const form = new FormData();
    form.set('language', language);
    form.set('audio', new Blob([await readFile(path)], { type: 'audio/wav' }), 'sample.wav');
    const response = await fetch(`${base}/api/voice-translate`, { method: 'POST', body: form });
    const body = await response.json();
    assert.equal(response.status, 200, JSON.stringify(body));
    assert.equal(body.success, true);
    assert.equal(body.language, language);
    assert.equal(body.targetLanguage, targetLanguage);
    assert.ok(body.transcript.trim());
    assert.ok(body.translatedText.trim());
    return body;
  };
  try {
    const hindi = await translateSample(hindiAudio, 'hi-IN', 'sat-IN');
    console.log(`REAL Hindi transcript: ${hindi.transcript}`);
    console.log(`REAL Hindi → Santali: ${hindi.translatedText}`);

    const santali = await translateSample(santaliAudio, 'sat-IN', 'hi-IN');
    console.log(`REAL Santali transcript: ${santali.transcript}`);
    console.log(`REAL Santali → Hindi: ${santali.translatedText}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
