import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import { apiRouter, getTranslationServiceHealth } from './routes/api_routes.js';
import { checkDatabase } from './config/database.js';

const app = express();
const port = Number(process.env.PORT ?? 3000);
const host = '0.0.0.0';
const isDevelopment = (process.env.NODE_ENV ?? 'development') !== 'production';

app.use(cors());
app.use(express.json({ limit: '1mb' }));

async function getDatabaseHealth() {
  if (!process.env.MYSQL_HOST || !process.env.MYSQL_DATABASE) {
    return 'not_configured';
  }

  try {
    await checkDatabase();
    return 'connected';
  } catch (error) {
    if (isDevelopment) {
      console.warn('[health] Database check failed:', error?.message ?? error);
    }
    return 'unavailable';
  }
}

async function healthHandler(_, response) {
  const [translation, database] = await Promise.all([
    getTranslationServiceHealth(),
    getDatabaseHealth(),
  ]);
  const modelReady = translation.modelReady === true;
  const ready = translation.reachable && translation.initialized && modelReady;

  return response.status(ready ? 200 : 503).json({
    status: ready ? 'ok' : 'degraded',
    backend: {
      running: true,
      host,
      port,
    },
    translation_service: {
      status: translation.status,
      reachable: translation.reachable,
      initialized: translation.initialized,
      model_ready: modelReady,
      model: translation.model,
      http_status: translation.httpStatus,
      error: translation.error,
    },
    // Keep these top-level fields for the existing diagnostic scripts.
    model: translation.model,
    model_loaded: modelReady,
    database,
  });
}

// /health is convenient for a phone/browser probe; /api/health remains
// backwards-compatible with the existing backend diagnostic script.
app.get('/health', healthHandler);
app.get('/api/health', healthHandler);
app.use('/api', apiRouter);

app.use((_, response) => response.status(404).json({ error: 'Route not found.' }));
app.use((error, _, response, __) => {
  console.error(error);
  response.status(500).json({ error: 'Unexpected server error.' });
});

app.listen(port, host, () => {
  console.log(`EduVaani backend listening on ${host}:${port}`);
  console.log(`Phone health check: http://<host-lan-ip>:${port}/health`);
});
