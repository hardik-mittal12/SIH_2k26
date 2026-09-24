import 'dotenv/config';
import { createApp } from './app.js';

const port = Number.parseInt(process.env.PORT ?? '3000', 10);
if (!Number.isInteger(port) || port < 1 || port > 65_535) {
  throw new Error('PORT must be an integer from 1 to 65535.');
}

const app = createApp();
const server = app.listen(port, '0.0.0.0', () => {
  console.log(`Santali Setu API listening on http://0.0.0.0:${port}`);
  if (!process.env.SARVAM_API_KEY?.trim()) {
    console.warn('SARVAM_API_KEY is not set. Health remains available; Sarvam endpoints will return a configuration error.');
  }
});

function shutdown(signal) {
  console.log(`${signal} received; closing HTTP server.`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.once('SIGINT', () => shutdown('SIGINT'));
process.once('SIGTERM', () => shutdown('SIGTERM'));
