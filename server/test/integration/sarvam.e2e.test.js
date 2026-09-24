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

test('real Hindi/Santali speech → Sarvam transcription → Sarvam translation', {
  skip: skipReason,
  timeout: 180_000,
}, async () => {
  const server = createServer(createApp());
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const speech = async (path, language) => {
    const form = new FormData();
    form.set('language', language);
    form.set('audio', new Blob([await readFile(path)], { type: 'audio/wav' }), 'sample.wav');
    const response = await fetch(`${base}/api/speech-to-text`, { method: 'POST', body: form });
    const body = await response.json();
    assert.equal(response.status, 200, JSON.stringify(body));
    assert.equal(body.success, true);
    assert.ok(body.text.trim());
    return body.text.trim();
  };
  const translate = async (text, sourceLanguage, targetLanguage) => {
    const response = await fetch(`${base}/api/translate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text, sourceLanguage, targetLanguage }),
    });
    const body = await response.json();
    assert.equal(response.status, 200, JSON.stringify(body));
    assert.equal(body.success, true);
    assert.ok(body.translatedText.trim());
    return body.translatedText.trim();
  };
  try {
    const hindiTranscript = await speech(hindiAudio, 'hi-IN');
    const santaliResult = await translate(hindiTranscript, 'hi-IN', 'sat-IN');
    console.log(`REAL Hindi STT: ${hindiTranscript}`);
    console.log(`REAL Hindi → Santali: ${santaliResult}`);

    const santaliTranscript = await speech(santaliAudio, 'sat-IN');
    const hindiResult = await translate(santaliTranscript, 'sat-IN', 'hi-IN');
    console.log(`REAL Santali STT: ${santaliTranscript}`);
    console.log(`REAL Santali → Hindi: ${hindiResult}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
