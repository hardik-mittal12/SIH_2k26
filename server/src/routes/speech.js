import { Router } from 'express';
import multer from 'multer';

export const SPEECH_LANGUAGES = new Set(['hi-IN', 'sat-IN']);
const MAX_AUDIO_BYTES = 10 * 1024 * 1024;
const MAX_AUDIO_SECONDS = 30;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_AUDIO_BYTES, files: 1, fields: 1 },
  fileFilter(_request, file, callback) {
    const nameLooksWav = file.originalname.toLowerCase().endsWith('.wav');
    const mimeLooksAudio = file.mimetype === 'audio/wav' ||
      file.mimetype === 'audio/x-wav' ||
      file.mimetype === 'application/octet-stream';
    callback(null, nameLooksWav && mimeLooksAudio);
  },
});

export function isSupportedPcmWav(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 44) return false;
  if (buffer.toString('ascii', 0, 4) !== 'RIFF' || buffer.toString('ascii', 8, 12) !== 'WAVE') return false;
  if (buffer.readUInt32LE(4) !== buffer.length - 8 ||
      buffer.toString('ascii', 12, 16) !== 'fmt ' ||
      buffer.toString('ascii', 36, 40) !== 'data') return false;
  const encoding = buffer.readUInt16LE(20);
  const channels = buffer.readUInt16LE(22);
  const sampleRate = buffer.readUInt32LE(24);
  const bitsPerSample = buffer.readUInt16LE(34);
  const dataBytes = buffer.readUInt32LE(40);
  const seconds = dataBytes / (sampleRate * channels * (bitsPerSample / 8));
  return encoding === 1 && channels === 1 && sampleRate === 16_000 &&
    bitsPerSample === 16 && dataBytes > 0 && seconds <= MAX_AUDIO_SECONDS &&
    dataBytes <= buffer.length - 44;
}

export function createSpeechRouter(sarvam) {
  const router = Router();
  router.post('/', upload.single('audio'), async (request, response, next) => {
    try {
      const language = request.body?.language;
      if (!SPEECH_LANGUAGES.has(language)) {
        return response.status(400).json({
          success: false,
          error: 'language must be hi-IN or sat-IN.',
          code: 'INVALID_LANGUAGE',
        });
      }
      if (!request.file) {
        return response.status(400).json({
          success: false,
          error: 'A WAV recording is required in the audio field.',
          code: 'AUDIO_REQUIRED',
        });
      }
      if (!isSupportedPcmWav(request.file.buffer)) {
        return response.status(400).json({
          success: false,
          error: 'Audio must be mono PCM16 WAV at 16 kHz and no longer than 30 seconds.',
          code: 'INVALID_AUDIO_FORMAT',
        });
      }
      const result = await sarvam.transcribe({
        audio: request.file.buffer,
        filename: request.file.originalname || 'recording.wav',
        contentType: 'audio/wav',
        languageCode: language,
      });
      return response.json({
        success: true,
        text: result.text,
        language: result.language,
        requestId: result.requestId,
      });
    } catch (error) {
      return next(error);
    }
  });
  return router;
}
