const SARVAM_ORIGIN = 'https://api.sarvam.ai';
export const SAARAS_MODEL = 'saaras:v4';
export const TRANSLATION_MODEL = 'sarvam-translate:v1';

export class SarvamApiError extends Error {
  constructor(message, { status = 502, code = 'SARVAM_UPSTREAM_ERROR', cause } = {}) {
    super(message, { cause });
    this.name = 'SarvamApiError';
    this.status = status;
    this.code = code;
  }
}

/** Server-only Sarvam client. Never instantiate this from Flutter. */
export function createSarvamService({
  apiKey = process.env.SARVAM_API_KEY,
  fetchImpl = globalThis.fetch,
  timeoutMs = 45_000,
} = {}) {
  if (typeof fetchImpl !== 'function') throw new TypeError('Fetch implementation is required.');

  function requireKey() {
    if (!apiKey?.trim()) {
      throw new SarvamApiError('Sarvam API key is not configured on the backend.', {
        status: 503,
        code: 'SARVAM_NOT_CONFIGURED',
      });
    }
    return apiKey.trim();
  }

  async function readJson(response) {
    let payload;
    try {
      payload = await response.json();
    } catch (cause) {
      throw new SarvamApiError('Sarvam returned an invalid response.', {
        status: 502,
        code: 'SARVAM_INVALID_RESPONSE',
        cause,
      });
    }
    if (!response.ok) {
      const status = response.status === 429 ? 503 : 502;
      throw new SarvamApiError(
        response.status === 429
          ? 'Sarvam is rate-limiting requests. Please try again shortly.'
          : 'Sarvam could not process this request. Please try again.',
        { status, code: response.status === 429 ? 'SARVAM_RATE_LIMITED' : 'SARVAM_REQUEST_FAILED' },
      );
    }
    return payload;
  }

  async function call(url, options) {
    const key = requireKey();
    try {
      return await fetchImpl(url, {
        ...options,
        headers: {
          ...options.headers,
          'api-subscription-key': key,
        },
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (cause) {
      if (cause?.name === 'TimeoutError' || cause?.name === 'AbortError') {
        throw new SarvamApiError('Sarvam request timed out. Please try again.', {
          status: 504,
          code: 'SARVAM_TIMEOUT',
          cause,
        });
      }
      throw new SarvamApiError('Could not connect to Sarvam AI. Please try again later.', {
        status: 502,
        code: 'SARVAM_UNAVAILABLE',
        cause,
      });
    }
  }

  return {
    get isConfigured() {
      return Boolean(apiKey?.trim());
    },

    async transcribe({ audio, filename = 'recording.wav', contentType = 'audio/wav', languageCode }) {
      const form = new FormData();
      form.set('file', new Blob([audio], { type: contentType }), filename);
      form.set('model', SAARAS_MODEL);
      form.set('mode', 'transcribe');
      form.set('language_code', languageCode);
      const response = await call(`${SARVAM_ORIGIN}/speech-to-text`, {
        method: 'POST',
        body: form,
      });
      const result = await readJson(response);
      if (typeof result?.transcript !== 'string' || !result.transcript.trim()) {
        throw new SarvamApiError('Sarvam returned no transcription.', {
          status: 502,
          code: 'SARVAM_EMPTY_TRANSCRIPT',
        });
      }
      return {
        text: result.transcript.trim(),
        language: result.language_code ?? languageCode,
        requestId: result.request_id ?? null,
      };
    },

    async translate({ text, sourceLanguage, targetLanguage }) {
      const response = await call(`${SARVAM_ORIGIN}/translate`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          input: text,
          source_language_code: sourceLanguage,
          target_language_code: targetLanguage,
          model: TRANSLATION_MODEL,
          mode: 'formal',
        }),
      });
      const result = await readJson(response);
      if (typeof result?.translated_text !== 'string' || !result.translated_text.trim()) {
        throw new SarvamApiError('Sarvam returned no translated text.', {
          status: 502,
          code: 'SARVAM_EMPTY_TRANSLATION',
        });
      }
      return {
        translatedText: result.translated_text.trim(),
        requestId: result.request_id ?? null,
      };
    },
  };
}
