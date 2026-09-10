import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';

/// Persistent, append-only session log for ASR transcription events.
///
/// Every call to [OnDeviceASRService.transcribeHindi] writes one JSON line to
/// `<appDocumentsDir>/asr_session.log` capturing both the raw model output
/// and the (possibly) corrected transcript after fuzzy matching.
///
/// Log format (one JSON object per line / JSONL):
/// ```json
/// {
///   "ts": "2026-09-10T09:41:00.000Z",
///   "raw": "न बस्ती",
///   "corrected": "नमस्ते",
///   "wasMatchApplied": true,
///   "similarityScore": 0.857,
///   "matchedCommand": "नमस्ते"
/// }
/// ```
///
/// The raw signal is **never discarded** — even when fuzzy correction is
/// applied the original CTC output is persisted for future threshold tuning.
class AsrSessionLogger {
  AsrSessionLogger._();
  static final AsrSessionLogger instance = AsrSessionLogger._();

  static const String _logFileName = 'asr_session.log';

  IOSink? _sink;
  bool _initialized = false;

  /// Opens (or creates) the log file for appending.
  /// Idempotent — safe to call multiple times.
  Future<void> _ensureOpen() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logFileName');
      _sink = file.openWrite(mode: FileMode.append);
      _initialized = true;
      _debugLog('ASR session log opened: ${file.path}');
    } catch (e) {
      _debugLog('Failed to open ASR session log: $e');
    }
  }

  /// Appends one structured JSON line for an ASR transcription event.
  ///
  /// This method is fire-and-forget — it does not block the ASR pipeline.
  /// If the log file cannot be written (e.g. on web or tests), the error
  /// is silently swallowed after a debug print.
  void log({
    required String rawTranscript,
    required String correctedTranscript,
    required bool wasMatchApplied,
    required double similarityScore,
    String? matchedCommand,
  }) {
    _writeAsync(
      rawTranscript: rawTranscript,
      correctedTranscript: correctedTranscript,
      wasMatchApplied: wasMatchApplied,
      similarityScore: similarityScore,
      matchedCommand: matchedCommand,
    );
  }

  Future<void> _writeAsync({
    required String rawTranscript,
    required String correctedTranscript,
    required bool wasMatchApplied,
    required double similarityScore,
    String? matchedCommand,
  }) async {
    try {
      await _ensureOpen();
      final sink = _sink;
      if (sink == null) return;

      final entry = jsonEncode({
        'ts': DateTime.now().toUtc().toIso8601String(),
        'raw': rawTranscript,
        'corrected': correctedTranscript,
        'wasMatchApplied': wasMatchApplied,
        'similarityScore': double.parse(similarityScore.toStringAsFixed(4)),
        ...?matchedCommand != null ? {'matchedCommand': matchedCommand} : null,
      });

      sink.writeln(entry);
      await sink.flush();
    } catch (e) {
      _debugLog('ASR session log write failed: $e');
    }
  }

  /// Returns the absolute path to the log file (for display in debug UI).
  Future<String?> get logFilePath async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$_logFileName';
    } catch (_) {
      return null;
    }
  }

  /// Closes the sink. Call from app dispose if needed.
  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _initialized = false;
  }

  void _debugLog(String msg) {
    if (kDebugMode) dev.log(msg, name: 'AsrSessionLogger');
  }
}
