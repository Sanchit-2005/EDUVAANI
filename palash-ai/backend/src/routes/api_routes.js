import { Router } from 'express';
import {
  getLesson,
  getLessons,
  getSimpleTable,
  getTranslations,
  saveProgress,
} from '../services/content_service.js';

export const apiRouter = Router();

// ── IndicTrans2 translation proxy ─────────────────────────────────────────────
//
// POST /api/translate
// Forwards the request to the Python FastAPI translation service and returns
// the model output to the Flutter client.
//
// Request body:
//   { "text": "नमस्ते", "source_language": "hin_Deva", "target_language": "sat_Olck" }
//
// Response (success):
//   { "success": true, "input": "...", "translation": "...",
//     "source_language": "...", "target_language": "..." }
//
// Response (error):
//   { "success": false, "error": "Human-readable message", "error_type": "model" }
//
// The Python service URL and timeout are read from environment variables so
// they are never hard-coded in source:
//   PYTHON_TRANSLATION_URL  (default: http://127.0.0.1:8000)
//   TRANSLATION_TIMEOUT_MS  (default: 30000)

const PYTHON_URL = (process.env.PYTHON_TRANSLATION_URL ?? 'http://127.0.0.1:8000')
  .replace(/\/$/, '');
const TIMEOUT_MS = Number(process.env.TRANSLATION_TIMEOUT_MS ?? 30_000);
const HEALTH_TIMEOUT_MS = Number(
  process.env.TRANSLATION_HEALTH_TIMEOUT_MS ?? 4_000,
);
const isDevelopment = (process.env.NODE_ENV ?? 'development') !== 'production';

const ALLOWED_LANGUAGES = new Set(['hin_Deva', 'sat_Olck']);
const ALLOWED_PAIRS = new Set(['hin_Deva→sat_Olck', 'sat_Olck→hin_Deva']);

function logDevelopment(message, ...args) {
  if (isDevelopment) console.log(message, ...args);
}

function logDevelopmentError(message, ...args) {
  if (isDevelopment) console.error(message, ...args);
}

function getUpstreamError(body) {
  if (typeof body?.detail === 'object' && body.detail !== null) {
    return body.detail.error ?? 'Translation failed. Please try again.';
  }
  if (typeof body?.detail === 'string') return body.detail;
  if (typeof body?.error === 'string') return body.error;
  return 'Translation failed. Please try again.';
}

/**
 * Check the Python service without loading the model. The Python app loads
 * IndicTrans2 once during its lifespan and only reports that state here.
 */
export async function getTranslationServiceHealth() {
  const endpoint = `${PYTHON_URL}/health`;
  logDevelopment(`[health] GET ${endpoint}`);

  let pythonResponse;
  try {
    pythonResponse = await fetch(endpoint, {
      method: 'GET',
      signal: AbortSignal.timeout(HEALTH_TIMEOUT_MS),
    });
  } catch (error) {
    logDevelopmentError(
      `[health] GET ${endpoint} failed (timeout/connection):`,
      error?.message ?? error,
    );
    return {
      status: 'unavailable',
      reachable: false,
      initialized: false,
      modelReady: false,
      model: null,
      httpStatus: null,
      error: 'Python translation service is unreachable.',
    };
  }

  logDevelopment(`[health] GET ${endpoint} -> HTTP ${pythonResponse.status}`);

  let body = null;
  try {
    body = await pythonResponse.json();
  } catch (error) {
    logDevelopmentError(
      `[health] GET ${endpoint} response parsing failed:`,
      error?.message ?? error,
    );
  }

  const modelReady = pythonResponse.ok && body?.model_loaded === true;
  const initialized = pythonResponse.ok && body?.status === 'ok';
  return {
    status: modelReady ? 'ready' : 'starting',
    reachable: true,
    initialized,
    modelReady,
    model: body?.model ?? null,
    httpStatus: pythonResponse.status,
    error: modelReady ? null : 'IndicTrans2 model is not ready.',
  };
}

apiRouter.post('/translate', async (request, response) => {
  const { text, source_language, target_language } = request.body ?? {};

  // ── Input validation ─────────────────────────────────────────────────────
  if (!text || typeof text !== 'string' || !text.trim()) {
    return response.status(422).json({
      success: false,
      error: 'text must not be empty.',
      error_type: 'request',
    });
  }
  if (!ALLOWED_LANGUAGES.has(source_language)) {
    return response.status(422).json({
      success: false,
      error: `Unsupported source_language: "${source_language}". Allowed: hin_Deva, sat_Olck`,
      error_type: 'request',
    });
  }
  if (!ALLOWED_LANGUAGES.has(target_language)) {
    return response.status(422).json({
      success: false,
      error: `Unsupported target_language: "${target_language}". Allowed: hin_Deva, sat_Olck`,
      error_type: 'request',
    });
  }
  if (!ALLOWED_PAIRS.has(`${source_language}→${target_language}`)) {
    return response.status(422).json({
      success: false,
      error: `Unsupported language pair: ${source_language} → ${target_language}`,
      error_type: 'request',
    });
  }

  // ── Forward to Python translation service ────────────────────────────────
  const endpoint = `${PYTHON_URL}/translate`;
  logDevelopment(`[translate] POST ${endpoint}`);

  let pythonResponse;
  try {
    pythonResponse = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: text.trim(),
        source_language,
        target_language,
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (error) {
    // Network error or timeout — Python service is unreachable from Node.
    const isTimeout = error?.name === 'TimeoutError' || error?.name === 'AbortError';
    logDevelopmentError(
      `[translate] POST ${endpoint} ${isTimeout ? 'timed out' : 'connection failed'}:`,
      error?.message ?? error,
    );
    return response.status(503).json({
      success: false,
      error: isTimeout
        ? 'Translation timed out. The model may still be loading — please retry in a moment.'
        : 'Translation service is unavailable. Please ensure the Python service is running.',
      // The Node endpoint was reached, but its Python dependency was not.
      // Keep this distinct from an inference failure so Flutter can offer the
      // network-unavailable state and a retry action.
      error_type: 'unavailable',
    });
  }

  logDevelopment(`[translate] POST ${endpoint} -> HTTP ${pythonResponse.status}`);

  // ── Relay the Python response ───────────────────────────────────────────
  let body;
  try {
    body = await pythonResponse.json();
  } catch (error) {
    logDevelopmentError(
      `[translate] POST ${endpoint} response parsing failed (HTTP ${pythonResponse.status}):`,
      error?.message ?? error,
    );
    return response.status(502).json({
      success: false,
      error: 'Translation service returned an unexpected response.',
      error_type: 'response',
    });
  }

  if (!pythonResponse.ok) {
    // Surface a safe model/request message — never expose stack traces.
    const errorMsg = getUpstreamError(body);
    const isModelError = pythonResponse.status >= 500;
    logDevelopmentError(
      `[translate] ${isModelError ? 'Python model error' : 'Python request error'} ` +
        `(HTTP ${pythonResponse.status}):`,
      errorMsg,
    );
    return response.status(isModelError
      ? (pythonResponse.status === 503 ? 503 : 502)
      : 422).json({
      success: false,
      error: errorMsg,
      error_type: isModelError ? 'model' : 'request',
    });
  }

  return response.json(body);
});

apiRouter.get('/lessons', async (_, response) => response.json({ data: await getLessons() }));
apiRouter.get('/lessons/:id', async (request, response) => {
  const lesson = await getLesson(Number(request.params.id));
  if (!lesson) return response.status(404).json({ error: 'Lesson not found.' });
  return response.json({ data: lesson });
});
apiRouter.get('/translations', async (_, response) => response.json({ data: await getTranslations() }));
apiRouter.get('/activities', async (_, response) => response.json({ data: await getSimpleTable('activities') }));
apiRouter.get('/assessments', async (_, response) => response.json({ data: await getSimpleTable('assessments') }));
apiRouter.get('/models', async (_, response) => response.json({ data: await getSimpleTable('model_versions') }));
apiRouter.post('/sync', async (_, response) => {
  const [lessons, translations, activities, assessments, models] = await Promise.all([
    getLessons(), getTranslations(), getSimpleTable('activities'), getSimpleTable('assessments'), getSimpleTable('model_versions'),
  ]);
  response.json({ data: { lessons, translations, activities, assessments, models }, syncedAt: new Date().toISOString() });
});
apiRouter.post('/progress', async (request, response) => {
  const id = await saveProgress(request.body ?? {});
  response.status(201).json({ message: 'Progress uploaded.', id });
});
