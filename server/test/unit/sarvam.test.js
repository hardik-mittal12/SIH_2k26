import test from 'node:test';
import assert from 'node:assert/strict';
import { createSarvamService, SAARAS_MODEL, TRANSLATION_MODEL } from '../../src/services/sarvam.js';

test('Saaras v4 request uses the documented multipart fields and server-only key', async () => {
  let observed;
  const service = createSarvamService({
    apiKey: 'test-only-key',
    fetchImpl: async (url, options) => {
      observed = { url, options };
      return Response.json({ transcript: 'नमस्ते', language_code: 'hi-IN', request_id: 'r1' });
    },
  });
  const result = await service.transcribe({
    audio: Buffer.from('RIFFfake'),
    filename: 'sample.wav',
    contentType: 'audio/wav',
    languageCode: 'hi-IN',
  });
  assert.equal(observed.url, 'https://api.sarvam.ai/speech-to-text');
  assert.equal(observed.options.headers['api-subscription-key'], 'test-only-key');
  assert.equal(observed.options.body.get('model'), SAARAS_MODEL);
  assert.equal(observed.options.body.get('mode'), 'transcribe');
  assert.equal(observed.options.body.get('language_code'), 'hi-IN');
  assert.equal(observed.options.body.get('file').name, 'sample.wav');
  assert.deepEqual(result, { text: 'नमस्ते', language: 'hi-IN', requestId: 'r1' });
});

test('Sarvam Translate uses sarvam-translate:v1 and returns provider output', async () => {
  let observed;
  const service = createSarvamService({
    apiKey: 'test-only-key',
    fetchImpl: async (url, options) => {
      observed = { url, options };
      return Response.json({ translated_text: 'ᱡᱚᱦᱟᱨ', request_id: 'r2' });
    },
  });
  const result = await service.translate({
    text: 'नमस्ते',
    sourceLanguage: 'hi-IN',
    targetLanguage: 'sat-IN',
  });
  assert.equal(observed.url, 'https://api.sarvam.ai/translate');
  assert.equal(observed.options.headers['api-subscription-key'], 'test-only-key');
  assert.deepEqual(JSON.parse(observed.options.body), {
    input: 'नमस्ते',
    source_language_code: 'hi-IN',
    target_language_code: 'sat-IN',
    model: TRANSLATION_MODEL,
    mode: 'formal',
  });
  assert.deepEqual(result, { translatedText: 'ᱡᱚᱦᱟᱨ', requestId: 'r2' });
});

test('missing credentials fail closed without calling Sarvam', async () => {
  let called = false;
  const service = createSarvamService({
    apiKey: '',
    fetchImpl: async () => { called = true; return Response.json({}); },
  });
  await assert.rejects(service.translate({
    text: 'text',
    sourceLanguage: 'hi-IN',
    targetLanguage: 'sat-IN',
  }), { code: 'SARVAM_NOT_CONFIGURED', status: 503 });
  assert.equal(called, false);
});

test('invalid Sarvam response is surfaced as a sanitized provider error', async () => {
  const service = createSarvamService({
    apiKey: 'test-only-key',
    fetchImpl: async () => Response.json({ translated_text: 19 }),
  });
  await assert.rejects(service.translate({
    text: 'text',
    sourceLanguage: 'hi-IN',
    targetLanguage: 'sat-IN',
  }), { code: 'SARVAM_EMPTY_TRANSLATION', status: 502 });
});
