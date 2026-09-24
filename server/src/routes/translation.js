import { Router } from 'express';

const LANGUAGE_PAIRS = new Set(['hi-IN:sat-IN', 'sat-IN:hi-IN']);
const MAX_TRANSLATION_CHARACTERS = 2_000;

export function createTranslationRouter(sarvam) {
  const router = Router();
  router.post('/', async (request, response, next) => {
    try {
      const { text, sourceLanguage, targetLanguage } = request.body ?? {};
      if (typeof text !== 'string' || !text.trim()) {
        return response.status(400).json({ success: false, error: 'text is required.', code: 'TEXT_REQUIRED' });
      }
      if ([...text].length > MAX_TRANSLATION_CHARACTERS) {
        return response.status(413).json({
          success: false,
          error: `Text must be no more than ${MAX_TRANSLATION_CHARACTERS} characters.`,
          code: 'TEXT_TOO_LONG',
        });
      }
      if (!LANGUAGE_PAIRS.has(`${sourceLanguage}:${targetLanguage}`)) {
        return response.status(400).json({
          success: false,
          error: 'Only hi-IN → sat-IN and sat-IN → hi-IN are supported.',
          code: 'UNSUPPORTED_LANGUAGE_PAIR',
        });
      }
      const result = await sarvam.translate({
        text: text.trim(),
        sourceLanguage,
        targetLanguage,
      });
      return response.json({
        success: true,
        translatedText: result.translatedText,
        requestId: result.requestId,
      });
    } catch (error) {
      return next(error);
    }
  });
  return router;
}
