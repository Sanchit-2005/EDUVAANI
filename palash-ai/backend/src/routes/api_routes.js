import { Router } from 'express';
import {
  getLesson,
  getLessons,
  getSimpleTable,
  getTranslations,
  saveProgress
} from '../services/content_service.js';

export const apiRouter = Router();

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
    getLessons(), getTranslations(), getSimpleTable('activities'), getSimpleTable('assessments'), getSimpleTable('model_versions')
  ]);
  response.json({ data: { lessons, translations, activities, assessments, models }, syncedAt: new Date().toISOString() });
});
apiRouter.post('/progress', async (request, response) => {
  const id = await saveProgress(request.body ?? {});
  response.status(201).json({ message: 'Progress uploaded.', id });
});
