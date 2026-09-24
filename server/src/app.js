import express from 'express';
import multer from 'multer';
import { createSpeechRouter } from './routes/speech.js';
import { createTranslationRouter } from './routes/translation.js';
import { createSarvamService, SarvamApiError } from './services/sarvam.js';

export function createApp({ sarvam = createSarvamService() } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '32kb', strict: true }));

  app.get('/health', (_request, response) => {
    response.json({
      status: 'ok',
      sarvamConfigured: sarvam.isConfigured,
      speechModel: 'saaras:v4',
      translationModel: 'sarvam-translate:v1',
    });
  });

  app.use('/api/speech-to-text', createSpeechRouter(sarvam));
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
