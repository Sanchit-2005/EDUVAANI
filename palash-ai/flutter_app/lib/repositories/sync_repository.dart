import '../database/database_helper.dart';
import '../models/sync_status.dart';
import 'package:sqflite/sqflite.dart';

class SyncRepository {
  Future<SyncStatus> getStatus() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseHelper.syncMetadataTable, limit: 1);
    return rows.isEmpty ? SyncStatus.empty : SyncStatus.fromMap(rows.first);
  }

  Future<void> saveStatus(SyncStatus status) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      DatabaseHelper.syncMetadataTable,
      status.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveDownloadedContent({
    required List<Map<String, dynamic>> lessons,
    required List<Map<String, dynamic>> translations,
    required SyncStatus status,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final lesson in lessons) {
      batch.insert(
        DatabaseHelper.lessonsTable,
        {
          'id': lesson['id'],
          'grade': lesson['grade'],
          'subject': lesson['subject'],
          'topic': lesson['topic'],
          'learningOutcome': lesson['learningOutcome'],
          'hindiInstruction': lesson['hindiInstruction'],
          'santaliTranslation': lesson['santaliTranslation'],
          'isPrototypeTranslation': lesson['isPrototypeTranslation'] == true || lesson['isPrototypeTranslation'] == 1 ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final translation in translations) {
      batch.insert(
        DatabaseHelper.translationsTable,
        {
          'id': translation['id'],
          'hindi': translation['hindi'],
          'santali': translation['santali'],
          'validationStatus': translation['validationStatus'] ?? 'prototype',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    batch.insert(
      DatabaseHelper.syncMetadataTable,
      status.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }
}
