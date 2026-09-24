import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createApp } from '../../src/app.js';

function makePcmWav(seconds = 1) {
  const dataBytes = 16_000 * seconds * 2;
  const wav = Buffer.alloc(44 + dataBytes);
  wav.write('RIFF', 0);
  wav.writeUInt32LE(36 + dataBytes, 4);
  wav.write('WAVE', 8);
  wav.write('fmt ', 12);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(16_000, 24);
  wav.writeUInt32LE(32_000, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write('data', 36);
  wav.writeUInt32LE(dataBytes, 40);
  return wav;
}

async function withServer(sarvam, run) {
  const server = createServer(createApp({ sarvam }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await run(base);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test('health reports configuration without exposing credentials', async () => {
  await withServer({ isConfigured: true }, async (base) => {
    const response = await fetch(`${base}/health`);
    const payload = await response.json();
    assert.equal(response.status, 200);
    assert.equal(payload.sarvamConfigured, true);
    assert.equal(JSON.stringify(payload).includes('test-only-key'), false);
  });
});

test('speech route validates 16k mono PCM WAV and passes chosen language', async () => {
  let requestSeen;
  await withServer({
    isConfigured: true,
    async transcribe(args) { requestSeen = args; return { text: 'नमस्ते, आप कैसे हैं?', language: args.languageCode, requestId: 'unit' }; },
  }, async (base) => {
    const form = new FormData();
    form.set('language', 'hi-IN');
    form.set('audio', new Blob([makePcmWav()], { type: 'audio/wav' }), 'recording.wav');
    const response = await fetch(`${base}/api/speech-to-text`, { method: 'POST', body: form });
    const payload = await response.json();
    assert.equal(response.status, 200);
    assert.equal(payload.text, 'नमस्ते, आप कैसे हैं?');
    assert.equal(requestSeen.languageCode, 'hi-IN');
    assert.equal(requestSeen.audio.length, makePcmWav().length);
  });
});

test('speech route forwards Santali language selection to the provider', async () => {
  let language;
  await withServer({
    isConfigured: true,
    async transcribe(args) { language = args.languageCode; return { text: 'ᱡᱚᱦᱟᱨ', language, requestId: null }; },
  }, async (base) => {
    const form = new FormData();
    form.set('language', 'sat-IN');
    form.set('audio', new Blob([makePcmWav()], { type: 'audio/wav' }), 'santali.wav');
    const response = await fetch(`${base}/api/speech-to-text`, { method: 'POST', body: form });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).language, 'sat-IN');
    assert.equal(language, 'sat-IN');
  });
});

test('speech route rejects a bad language before provider call', async () => {
  let called = false;
  await withServer({
    isConfigured: true,
    async transcribe() { called = true; throw new Error('must not be called'); },
  }, async (base) => {
    const form = new FormData();
    form.set('language', 'en-US');
    form.set('audio', new Blob([makePcmWav()], { type: 'audio/wav' }), 'recording.wav');
    const response = await fetch(`${base}/api/speech-to-text`, { method: 'POST', body: form });
    assert.equal(response.status, 400);
    assert.equal((await response.json()).code, 'INVALID_LANGUAGE');
    assert.equal(called, false);
  });
});

test('translation route uses selected direction and rejects unrelated pairs', async () => {
  let requestSeen;
  await withServer({
    isConfigured: true,
    async translate(args) { requestSeen = args; return { translatedText: 'ᱡᱚᱦᱟᱨ', requestId: 'unit' }; },
  }, async (base) => {
    const response = await fetch(`${base}/api/translate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'नमस्ते', sourceLanguage: 'hi-IN', targetLanguage: 'sat-IN' }),
    });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).translatedText, 'ᱡᱚᱦᱟᱨ');
    assert.deepEqual(requestSeen, { text: 'नमस्ते', sourceLanguage: 'hi-IN', targetLanguage: 'sat-IN' });

    const reverse = await fetch(`${base}/api/translate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'ᱡᱚᱦᱟᱨ', sourceLanguage: 'sat-IN', targetLanguage: 'hi-IN' }),
    });
    assert.equal(reverse.status, 200);
    assert.equal(requestSeen.sourceLanguage, 'sat-IN');
    assert.equal(requestSeen.targetLanguage, 'hi-IN');

    const invalid = await fetch(`${base}/api/translate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'x', sourceLanguage: 'en-IN', targetLanguage: 'sat-IN' }),
    });
    assert.equal(invalid.status, 400);
  });
});
