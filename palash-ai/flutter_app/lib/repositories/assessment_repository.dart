import '../database/database_helper.dart';
import '../models/assessment.dart';

class AssessmentRepository {
  AssessmentRepository({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  Future<void> saveQuestions(List<AssessmentQuestion> questions) async {
    final db = await _database.database;
    final batch = db.batch();
    for (final question in questions) {
      batch.insert(DatabaseHelper.assessmentsTable, question.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<AssessmentQuestion>> getQuestions() async {
    final db = await _database.database;
    final rows = await db.query(
      DatabaseHelper.assessmentsTable,
      orderBy: 'id DESC',
    );
    return rows.map((row) => AssessmentQuestion.fromMap(row)).toList();
  }
}
