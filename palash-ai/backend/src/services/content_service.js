import { getDatabase } from '../config/database.js';

const sanitizedSantaliTranslation = `NULLIF(TRIM(REPLACE(santali_translation, '[Prototype Santali Translation]', '')), '')`;

export async function getLessons() {
  const [rows] = await getDatabase().query(
    `SELECT id, grade, subject, topic, learning_outcome AS learningOutcome, hindi_instruction AS hindiInstruction, ${sanitizedSantaliTranslation} AS santaliTranslation, is_prototype_translation AS isPrototypeTranslation FROM lessons ORDER BY id`,
  );
  return rows;
}

export async function getLesson(id) {
  const [rows] = await getDatabase().query(
    `SELECT id, grade, subject, topic, learning_outcome AS learningOutcome, hindi_instruction AS hindiInstruction, ${sanitizedSantaliTranslation} AS santaliTranslation, is_prototype_translation AS isPrototypeTranslation FROM lessons WHERE id = ?`,
    [id],
  );
  return rows[0] ?? null;
}

export async function getTranslations() {
  const [rows] = await getDatabase().query(
    'SELECT id, hindi, santali, validation_status AS validationStatus FROM translations ORDER BY id',
  );
  return rows;
}

export async function getSimpleTable(table) {
  const allowed = new Set(['activities', 'assessments', 'model_versions']);
  if (!allowed.has(table)) throw new Error('Unsupported content table.');
  const [rows] = await getDatabase().query(`SELECT * FROM ${table} ORDER BY id`);
  return rows;
}

export async function saveProgress(progress) {
  const [result] = await getDatabase().execute(
    'INSERT INTO progress (class_name, students, lessons_completed, total_lessons, literacy_percent, numeracy_percent, vocabulary_percent) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [
      progress.className,
      progress.students,
      progress.lessonsCompleted,
      progress.totalLessons,
      progress.literacyPercent,
      progress.numeracyPercent,
      progress.vocabularyPercent,
    ],
  );
  return result.insertId;
}
