import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/scan_result.dart';

/// Repository for scan history persistence.
///
/// Handles all database operations related to Santali scan results.
class ScanRepository {
  ScanRepository(this._databaseHelper);

  final DatabaseHelper _databaseHelper;

  /// Insert a new scan result
  Future<int> insertScan(ScanResult scan) async {
    final db = await _databaseHelper.database;
    return db.insert(
      DatabaseHelper.scanHistoryTable,
      scan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all scan results, ordered by most recent first
  Future<List<ScanResult>> getAllScans() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.scanHistoryTable,
      orderBy: 'created_at DESC',
    );
    return maps.map(ScanResult.fromMap).toList();
  }

  /// Get a specific scan result by ID
  Future<ScanResult?> getScanById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.scanHistoryTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ScanResult.fromMap(maps.first);
  }

  /// Get scan results by date range
  Future<List<ScanResult>> getScansByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.scanHistoryTable,
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return maps.map(ScanResult.fromMap).toList();
  }

  /// Search scans by Santali text
  Future<List<ScanResult>> searchSantaliText(String query) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.scanHistoryTable,
      where: 'santali_text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
    return maps.map(ScanResult.fromMap).toList();
  }

  /// Update a scan result (e.g., mark as synced)
  Future<int> updateScan(ScanResult scan) async {
    final db = await _databaseHelper.database;
    return db.update(
      DatabaseHelper.scanHistoryTable,
      scan.toMap(),
      where: 'id = ?',
      whereArgs: [scan.id],
    );
  }

  /// Delete a scan result
  Future<int> deleteScan(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(
      DatabaseHelper.scanHistoryTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get count of all scans
  Future<int> getScanCount() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.scanHistoryTable}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get scans that haven't been synced yet
  Future<List<ScanResult>> getUnSyncedScans() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      DatabaseHelper.scanHistoryTable,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
    return maps.map(ScanResult.fromMap).toList();
  }

  /// Mark scan as synced
  Future<int> markSynced(int id) async {
    final db = await _databaseHelper.database;
    return db.update(
      DatabaseHelper.scanHistoryTable,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all scan history (use with caution)
  Future<int> clearAllScans() async {
    final db = await _databaseHelper.database;
    return db.delete(DatabaseHelper.scanHistoryTable);
  }
}
