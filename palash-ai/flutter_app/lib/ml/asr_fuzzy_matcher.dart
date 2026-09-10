import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../services/translation_service.dart';

/// Result from a fuzzy-match attempt against the classroom command list.
class FuzzyMatchResult {
  const FuzzyMatchResult({
    required this.correctedTranscript,
    required this.rawTranscript,
    required this.wasMatchApplied,
    required this.similarityScore,
    this.matchedCommand,
  });

  /// The final transcript to use downstream (corrected if matched, raw otherwise).
  final String correctedTranscript;

  /// The original, unmodified ASR output string.
  final String rawTranscript;

  /// True when the fuzzy matcher replaced the raw text with a known command.
  final bool wasMatchApplied;

  /// Normalized Levenshtein similarity in [0.0, 1.0].
  /// 1.0 = exact match, 0.0 = completely different.
  final double similarityScore;

  /// The command string from the known list that was matched (if any).
  final String? matchedCommand;
}

/// Post-processing layer that snaps near-miss CTC outputs to known classroom
/// commands using normalized Levenshtein edit distance.
///
/// **When correction activates**:
///   - The raw ASR output has ≤ [_maxTokensForCorrection] tokens (whitespace-split).
///   - The best candidate command similarity ≥ [threshold].
///   - Multi-word utterances above the token limit pass through unchanged.
///
/// **Command list**:
///   Combined from:
///   1. Hindi strings from [MockTranslationService.phrases] (full classroom phrases).
///   2. [_standaloneCommands] — short words that appear as genuine isolated
///      teacher utterances but don't appear as stand-alone phrases in the list.
class ClassroomCommandFuzzyMatcher {
  ClassroomCommandFuzzyMatcher({this.threshold = 0.75});

  /// Normalized similarity threshold — 0.75 means at most 25% of characters
  /// can differ before we decline to auto-correct.
  final double threshold;

  /// Maximum token count (whitespace-split) for correction to be considered.
  /// Full-sentence utterances above this pass through unchanged.
  static const int _maxTokensForCorrection = 4;

  /// For very short inputs (≤ [_shortWordRuneThreshold] runes), a lower
  /// similarity threshold is used because one character substitution already
  /// represents ≥25% of the string — pushing sim below the main threshold.
  ///
  /// Empirically derived from Sept-2026 CTC benchmark:
  ///   'रुकुर' → 'रुको'  sim=0.60  (needs ≤0.65 to fire)
  ///   'सुनुक' → 'सुनो'  sim=0.60  (needs ≤0.65 to fire)
  ///   'बैठ'   → 'बैठो'  sim=0.75  (fires at default threshold)
  ///   'रुक'   → 'रुको'  sim=0.75  (fires at default threshold)
  static const int _shortWordRuneThreshold = 5;
  static const double _shortWordThreshold = 0.60;

  /// Short standalone classroom commands that teachers say in isolation but
  /// that are not full-phrase entries in [MockTranslationService.phrases].
  static const List<String> _standaloneCommands = [
    'नमस्ते',
    'धन्यवाद',
    'रुको',
    'सुनो',
    'देखो',
    'पढ़ो',
    'लिखो',
    'खोलो',
    'बैठो',
    'बोलो',
    'खेलो',
    'बंद करो',
    'आओ',
    'जाओ',
    'हाँ',
    'नहीं',
    'ठीक है',
    'शाबाश',
  ];

  /// Lazily built full command list (phrase hindiText + standalone words).
  List<String>? _commandList;

  List<String> get _commands {
    _commandList ??= [
      ..._standaloneCommands,
      ...MockTranslationService.phrases.map((p) => _stripPunctuation(p.hindi)),
    ];
    return _commandList!;
  }

  /// Applies fuzzy matching to [rawAsrOutput].
  ///
  /// Returns a [FuzzyMatchResult] with the corrected transcript (or raw if no
  /// match exceeded [threshold]), plus logging metadata.
  FuzzyMatchResult matchCommand(String rawAsrOutput) {
    final raw = rawAsrOutput.trim();

    // Guard: empty input
    if (raw.isEmpty) {
      return FuzzyMatchResult(
        correctedTranscript: raw,
        rawTranscript: raw,
        wasMatchApplied: false,
        similarityScore: 0.0,
      );
    }

    // Guard: too many tokens — full-sentence pass-through
    final tokenCount = raw.split(RegExp(r'\s+')).length;
    if (tokenCount > _maxTokensForCorrection) {
      _debugLog('Pass-through ($tokenCount tokens > $_maxTokensForCorrection): "$raw"');
      return FuzzyMatchResult(
        correctedTranscript: raw,
        rawTranscript: raw,
        wasMatchApplied: false,
        similarityScore: 0.0,
      );
    }

    // Find best match
    String? bestCommand;
    double bestScore = 0.0;

    final normalizedRaw = _stripPunctuation(raw);
    final rawRunes = normalizedRaw.runes.toList();
    final rawNoSpaces = normalizedRaw.replaceAll(' ', '');
    final isShortWord = rawRunes.length <= _shortWordRuneThreshold;

    for (final command in _commands) {
      final cmdRunes = command.runes.toList();

      // Guard against false-positive rhyming minimal pairs on short words:
      // In Hindi phonetics, ASR CTC errors for isolated words involve vowel drift,
      // suffix drop, or aspiration, but NOT substitution of the entire initial consonant.
      // Requiring the initial onset rune to match for short words (<= 5 runes) prevents
      // false rhyming corrections like "धोलो" -> "खोलो", "चुनो" -> "सुनो", or "गुनो" -> "सुनो".
      if (isShortWord && rawRunes.isNotEmpty && cmdRunes.isNotEmpty && rawRunes.first != cmdRunes.first) {
        continue;
      }

      double score = _normalizedSimilarity(normalizedRaw, command);

      // If target command is single-word (no space) and raw output contains spaces
      // inserted by CTC (e.g. "खो लो" -> "खोलो", "न बस्ते" -> "नमस्ते"), evaluate
      // similarity with spaces collapsed as well to heal CTC blank insertions.
      if (!command.contains(' ') && normalizedRaw.contains(' ')) {
        final scoreNoSpace = _normalizedSimilarity(rawNoSpaces, command);
        if (scoreNoSpace > score) score = scoreNoSpace;
      }

      if (score > bestScore) {
        bestScore = score;
        bestCommand = command;
      }
    }

    // Determine effective threshold: use shortWordThreshold for short words (<= 5 runes).
    final effectiveThreshold = isShortWord ? _shortWordThreshold : threshold;

    if (bestScore >= effectiveThreshold && bestCommand != null) {
      _debugLog(
        'Fuzzy match: "$raw" → "$bestCommand" '
        '(score=${bestScore.toStringAsFixed(3)})',
      );
      return FuzzyMatchResult(
        correctedTranscript: bestCommand,
        rawTranscript: raw,
        wasMatchApplied: true,
        similarityScore: bestScore,
        matchedCommand: bestCommand,
      );
    }

    _debugLog(
      'No match above threshold: "$raw" '
      '(best="${bestCommand ?? "none"}", score=${bestScore.toStringAsFixed(3)})',
    );
    return FuzzyMatchResult(
      correctedTranscript: raw,
      rawTranscript: raw,
      wasMatchApplied: false,
      similarityScore: bestScore,
      matchedCommand: bestCommand,
    );
  }

  // ── Levenshtein similarity ─────────────────────────────────────────────────

  /// Returns normalized similarity in [0.0, 1.0]:
  ///   similarity = 1.0 - (editDistance / max(len(a), len(b)))
  double _normalizedSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Work at the grapheme cluster level using runes (covers Devanagari
    // multi-codepoint characters correctly for distance purposes).
    final aRunes = a.runes.toList();
    final bRunes = b.runes.toList();
    final distance = _levenshteinDistance(aRunes, bRunes);
    final maxLen = aRunes.length > bRunes.length ? aRunes.length : bRunes.length;
    return 1.0 - (distance / maxLen);
  }

  /// Classic Wagner–Fischer Levenshtein edit distance on integer codepoint lists.
  /// Space-optimized to O(min(m,n)) using two rolling rows.
  int _levenshteinDistance(List<int> a, List<int> b) {
    // Ensure a is the shorter sequence for the O(min) optimization.
    final src = a.length <= b.length ? a : b;
    final tgt = a.length <= b.length ? b : a;

    var prev = List<int>.generate(src.length + 1, (i) => i);
    var curr = List<int>.filled(src.length + 1, 0);

    for (int j = 1; j <= tgt.length; j++) {
      curr[0] = j;
      for (int i = 1; i <= src.length; i++) {
        final cost = src[i - 1] == tgt[j - 1] ? 0 : 1;
        final deleteCost = prev[i] + 1;
        final insertCost = curr[i - 1] + 1;
        final replaceCost = prev[i - 1] + cost;
        curr[i] = _min3(deleteCost, insertCost, replaceCost);
      }
      // Swap rows
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[src.length];
  }

  int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= c) return b;
    return c;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Strips common Hindi/Devanagari punctuation for comparison normalization.
  String _stripPunctuation(String s) =>
      s.replaceAll(RegExp(r'[।?!,.।]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  void _debugLog(String msg) {
    if (kDebugMode) dev.log(msg, name: 'ASRFuzzyMatcher');
  }
}
