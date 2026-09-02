import '../database/database_helper.dart';
import '../models/progress_record.dart';

class ProgressRepository {
  ProgressRepository({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  Future<ProgressRecord> getGradeOneProgress() async {
    final db = await _database.database;
    final rows = await db.query(
      DatabaseHelper.progressTable,
      where: 'className = ?',
      whereArgs: ['Grade 1'],
      limit: 1,
    );
    if (rows.isNotEmpty) return ProgressRecord.fromMap(rows.first);

    final progress = const ProgressRecord(
      className: 'Grade 1',
      students: 24,
      lessonsCompleted: 0,
      totalLessons: 15,
      literacyPercent: 0,
      numeracyPercent: 0,
      vocabularyPercent: 0,
    );
    final id = await db.insert(DatabaseHelper.progressTable, progress.toMap());
    return ProgressRecord(
      id: id,
      className: progress.className,
      students: progress.students,
      lessonsCompleted: progress.lessonsCompleted,
      totalLessons: progress.totalLessons,
      literacyPercent: progress.literacyPercent,
      numeracyPercent: progress.numeracyPercent,
      vocabularyPercent: progress.vocabularyPercent,
    );
  }

  Future<ProgressRecord> completeNextLesson(ProgressRecord current) async {
    final completed = (current.lessonsCompleted + 1)
        .clamp(0, current.totalLessons)
        .toInt();
    final ratio = completed / current.totalLessons;
    final updated = ProgressRecord(
      id: current.id,
      className: current.className,
      students: current.students,
      lessonsCompleted: completed,
      totalLessons: current.totalLessons,
      literacyPercent: (ratio * 70).round(),
      numeracyPercent: (ratio * 90).round(),
      vocabularyPercent: (ratio * 60).round(),
    );
    final db = await _database.database;
    await db.update(
      DatabaseHelper.progressTable,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    return updated;
  }
}
