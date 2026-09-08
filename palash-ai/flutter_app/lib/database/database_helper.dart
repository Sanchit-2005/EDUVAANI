import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/custom_assignment.dart';
import '../models/lesson.dart';
import 'seed_data.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'eduvaani.db';
  static const _dbVersion = 10;
  static const lessonsTable = 'lessons';
  static const assessmentsTable = 'assessments';
  static const progressTable = 'progress';
  static const syncMetadataTable = 'sync_metadata';
  static const translationsTable = 'translations';
  static const benchmarkTable = 'benchmark_results';
  static const scanHistoryTable = 'scan_history';
  static const customAssignmentsTable = 'custom_assignments';
  static const lessonCompletionsTable = 'lesson_completions';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $lessonsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade TEXT NOT NULL,
        subject TEXT NOT NULL,
        topic TEXT NOT NULL,
        learningOutcome TEXT NOT NULL,
        hindiInstruction TEXT NOT NULL,
        santaliTranslation TEXT,
        isPrototypeTranslation INTEGER NOT NULL DEFAULT 0,
        sequenceNumber INTEGER NOT NULL DEFAULT 1,
        durationMinutes INTEGER NOT NULL DEFAULT 20,
        santaliQualityStatus TEXT NOT NULL DEFAULT 'unverified'
      )
    ''');
    await _createAssessmentsTable(db);
    await _createProgressTable(db);
    await _createSyncMetadataTable(db);
    await _createTranslationsTable(db);
    await _createBenchmarkTable(db);
    await _createScanHistoryTable(db);
    await _createCustomAssignmentsTable(db);
    await _createLessonCompletionsTable(db);
    await SeedData.insertSeedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createAssessmentsTable(db);
    if (oldVersion < 3) await _createProgressTable(db);
    if (oldVersion < 4) await _createSyncMetadataTable(db);
    if (oldVersion < 5) await _createTranslationsTable(db);
    if (oldVersion < 6) await _createBenchmarkTable(db);
    if (oldVersion < 7) await _createScanHistoryTable(db);
    if (oldVersion < 8) await _createCustomAssignmentsTable(db);
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE $lessonsTable ADD COLUMN sequenceNumber INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE $lessonsTable ADD COLUMN durationMinutes INTEGER NOT NULL DEFAULT 20',
      );
      await db.execute(
        "ALTER TABLE $lessonsTable ADD COLUMN santaliQualityStatus TEXT NOT NULL DEFAULT 'unverified'",
      );
      await SeedData.applyLessonMetadata(db);
    }
    if (oldVersion < 10) await _createLessonCompletionsTable(db);
  }

  Future<void> _createAssessmentsTable(Database db) => db.execute('''
      CREATE TABLE $assessmentsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade TEXT NOT NULL,
        subject TEXT NOT NULL,
        topic TEXT NOT NULL,
        questionNumber INTEGER NOT NULL,
        hindiText TEXT NOT NULL,
        santaliText TEXT NOT NULL
      )
    ''');

  Future<void> _createProgressTable(Database db) => db.execute('''
      CREATE TABLE $progressTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        className TEXT NOT NULL UNIQUE,
        students INTEGER NOT NULL,
        lessonsCompleted INTEGER NOT NULL,
        totalLessons INTEGER NOT NULL,
        literacyPercent INTEGER NOT NULL,
        numeracyPercent INTEGER NOT NULL,
        vocabularyPercent INTEGER NOT NULL
      )
    ''');

  Future<void> _createSyncMetadataTable(Database db) => db.execute('''
      CREATE TABLE $syncMetadataTable (
        id INTEGER PRIMARY KEY,
        lastSyncedAt TEXT,
        downloadedLessons INTEGER NOT NULL,
        downloadedTranslations INTEGER NOT NULL,
        downloadedModels INTEGER NOT NULL
      )
    ''');

  Future<void> _createTranslationsTable(Database db) => db.execute('''
      CREATE TABLE $translationsTable (
        id INTEGER PRIMARY KEY,
        hindi TEXT NOT NULL,
        santali TEXT NOT NULL,
        validationStatus TEXT NOT NULL
      )
    ''');

  Future<void> _createBenchmarkTable(Database db) => db.execute('''
      CREATE TABLE $benchmarkTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asrMs INTEGER NOT NULL,
        translationMs INTEGER NOT NULL,
        ttsMs INTEGER NOT NULL,
        totalMs INTEGER NOT NULL,
        recordedAt TEXT NOT NULL
      )
    ''');

  Future<void> _createScanHistoryTable(Database db) => db.execute('''
      CREATE TABLE $scanHistoryTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        santali_text TEXT NOT NULL,
        hindi_translation TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

  Future<void> _createCustomAssignmentsTable(Database db) => db.execute('''
      CREATE TABLE $customAssignmentsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade TEXT NOT NULL,
        subject TEXT NOT NULL,
        topic TEXT NOT NULL,
        questions_json TEXT NOT NULL,
        include_hindi INTEGER NOT NULL DEFAULT 1,
        include_santali INTEGER NOT NULL DEFAULT 1,
        include_english INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

  Future<void> _createLessonCompletionsTable(Database db) => db.execute('''
      CREATE TABLE $lessonCompletionsTable (
        lesson_id INTEGER PRIMARY KEY,
        completed_at TEXT NOT NULL
      )
    ''');

  Future<List<Lesson>> getLessons({String? grade, String? subject}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (grade != null && grade.isNotEmpty) {
      where.add('grade = ?');
      args.add(grade);
    }
    if (subject != null && subject.isNotEmpty) {
      where.add('subject = ?');
      args.add(subject);
    }
    final rows = await db.query(
      lessonsTable,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'grade ASC, subject ASC, sequenceNumber ASC, topic ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }

  Future<List<String>> getGrades() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT grade FROM $lessonsTable ORDER BY grade',
    );
    return rows.map((row) => row['grade'] as String).toList();
  }

  Future<List<String>> getSubjects() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT subject FROM $lessonsTable ORDER BY subject',
    );
    return rows.map((row) => row['subject'] as String).toList();
  }

  // ── Per-lesson completion tracking ─────────────────────────────────────

  Future<Set<int>> getCompletedLessonIds() async {
    final db = await database;
    final rows = await db.query(lessonCompletionsTable, columns: ['lesson_id']);
    return rows.map((row) => row['lesson_id'] as int).toSet();
  }

  Future<bool> toggleLessonCompletion(int lessonId) async {
    final db = await database;
    final existing = await db.query(
      lessonCompletionsTable,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.delete(
        lessonCompletionsTable,
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );
      return false;
    }
    await db.insert(lessonCompletionsTable, {
      'lesson_id': lessonId,
      'completed_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  // ── Custom assignments CRUD ─────────────────────────────────────────────

  Future<int> insertCustomAssignment(CustomAssignment assignment) async {
    final db = await database;
    return db.insert(customAssignmentsTable, assignment.toMap());
  }

  Future<List<CustomAssignment>> getCustomAssignments() async {
    final db = await database;
    final rows = await db.query(
      customAssignmentsTable,
      orderBy: 'created_at DESC',
    );
    return rows.map(CustomAssignment.fromMap).toList();
  }

  Future<int> updateCustomAssignment(CustomAssignment assignment) async {
    final db = await database;
    return db.update(
      customAssignmentsTable,
      assignment.toMap(),
      where: 'id = ?',
      whereArgs: [assignment.id],
    );
  }

  Future<int> deleteCustomAssignment(int id) async {
    final db = await database;
    return db.delete(
      customAssignmentsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _database = null;
  }
}
