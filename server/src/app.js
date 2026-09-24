import express from 'express';
import multer from 'multer';
import { rateLimit } from 'express-rate-limit';
import { createSpeechRouter } from './routes/speech.js';
import { createTranslationRouter } from './routes/translation.js';
import { createSarvamService, SarvamApiError } from './services/sarvam.js';

export function createApp({ sarvam = createSarvamService() } = {}) {
  const app = express();
  app.disable('x-powered-by');
  // Native Flutter clients do not send browser credentials. Wildcard CORS keeps
  // optional browser-based demos usable without enabling credentialed requests.
  app.use((request, response, next) => {
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept');
    response.setHeader('Access-Control-Max-Age', '600');
    if (request.method === 'OPTIONS') return response.sendStatus(204);
    next();
  });
  app.use(express.json({ limit: '32kb', strict: true }));

  app.get('/health', (_request, response) => {
    response.json({
      status: 'ok',
      sarvamConfigured: sarvam.isConfigured,
      speechModel: 'saaras:v4',
      translationModel: 'sarvam-translate:v1',
    });
  });

  app.use('/api', rateLimit({
    windowMs: 60_000,
    limit: 30,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      error: 'Too many requests. Please wait a moment and try again.',
      code: 'RATE_LIMITED',
    },
  }));

  app.use('/api/speech-to-text', createSpeechRouter(sarvam));
  app.use('/api/voice-translate', createSpeechRouter(sarvam, { translateAudio: true }));
  app.use('/api/translate', createTranslationRouter(sarvam));

  app.use((_request, response) => {
    response.status(404).json({ success: false, error: 'Endpoint not found.', code: 'NOT_FOUND' });
  });

  // Centralized, sanitized API errors. Never send provider payloads or stack traces to the phone.
  app.use((error, _request, response, _next) => {
    if (error instanceof multer.MulterError) {
      const tooLarge = error.code === 'LIMIT_FILE_SIZE';
      return response.status(tooLarge ? 413 : 400).json({
        success: false,
        error: tooLarge ? 'Audio is too large; recordings are limited to 10 MB.' : 'Invalid multipart audio request.',
        code: tooLarge ? 'AUDIO_TOO_LARGE' : error.code,
      });
    }
    if (error?.type === 'entity.too.large') {
      return response.status(413).json({ success: false, error: 'Request body is too large.', code: 'BODY_TOO_LARGE' });
    }
    if (error instanceof SyntaxError && 'body' in error) {
      return response.status(400).json({ success: false, error: 'Request JSON is invalid.', code: 'INVALID_JSON' });
    }
    if (error instanceof SarvamApiError) {
      return response.status(error.status).json({
        success: false,
        error: error.message,
        code: error.code,
      });
    }
    console.error('Unhandled request failure:', error?.message ?? 'unknown error');
    return response.status(500).json({
      success: false,
      error: 'The service encountered an unexpected error. Please try again.',
      code: 'INTERNAL_ERROR',
    });
  });
  return app;
}
