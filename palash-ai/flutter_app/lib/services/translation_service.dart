import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class TranslationResult {
  const TranslationResult({
    required this.source,
    required this.output,
    required this.isPrototype,
    required this.matchedPhrase,
    this.note,
  });

  final String source;
  final String output;

  /// true  → legacy mock/dictionary result (phrase-tile quick-fill only)
  /// false → real IndicTrans2 model result
  final bool isPrototype;

  /// true only when a phrase-tile exact match was used (mock path)
  final bool matchedPhrase;

  final String? note;
}

class ClassroomPhrase {
  const ClassroomPhrase({
    required this.id,
    required this.hindi,
    required this.santali,
    required this.englishHint,
  });

  final String id;
  final String hindi;
  final String santali;
  final String englishHint;
}

// ── Abstract contract ─────────────────────────────────────────────────────────

abstract class TranslationService {
  const TranslationService();

  /// The active translation service used by [TextTranslatorScreen].
  /// Points at [ApiTranslationService] which calls the real IndicTrans2 model.
  static final TranslationService instance = ApiTranslationService();

  /// Classroom phrase list — used by phrase-tiles and the mock path.
  static List<ClassroomPhrase> get phrases => MockTranslationService.phrases;

  /// Translate [text] using the IndicTrans2 ML model via the backend API.
  ///
  /// IMPORTANT: This always calls the ML model. The offline dictionary is
  /// NEVER used as a fallback for this method. If the backend is unreachable,
  /// a [TranslationApiException] is thrown.
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });

  /// Dictionary-based Hindi → Santali (mock, used for phrase-tile quick-fill only).
  TranslationResult hindiToSantali(String input);

  /// Dictionary-based Santali → Hindi (mock, used for phrase-tile quick-fill only).
  TranslationResult santaliToHindi(String input);
}

// ── Typed exception ───────────────────────────────────────────────────────────

enum TranslationFailureKind { unavailable, model, response, request }

class TranslationApiException implements Exception {
  const TranslationApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.technicalMessage,
  });

  final TranslationFailureKind kind;
  final String message;
  final int? statusCode;

  /// Developer-only detail. Never render this directly in the UI.
  final String? technicalMessage;

  bool get isUnavailable => kind == TranslationFailureKind.unavailable;
  bool get isModelError => kind == TranslationFailureKind.model;

  @override
  String toString() =>
      'TranslationApiException(kind: $kind, status: $statusCode, message: $message)';
}

// ── Real API service (IndicTrans2 via Node.js → Python) ───────────────────────
//
// Translation flow:
//   Flutter ──► Node.js ──► Python FastAPI ──► IndicTrans2 ──► result
//
// The ML model is ALWAYS the primary engine for translate().
// The offline dictionary (MockTranslationService) is only used by the sync
// helpers hindiToSantali() and santaliToHindi() which power phrase-tiles.
// "No dictionary match" can NEVER appear as a translate() result.

class ApiTranslationService implements TranslationService {
  ApiTranslationService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// In-memory translation cache: key = "src|tgt|text", value = result.
  /// Capped at 100 entries; oldest entry evicted on overflow (insertion order).
  final Map<String, TranslationResult> _cache = {};
  static const int _maxCacheSize = 100;

  String _cacheKey(String text, String src, String tgt) => '$src|$tgt|$text';

  // ── translate() — ML model is always primary ──────────────────────────────

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const TranslationApiException(
        kind: TranslationFailureKind.request,
        message: 'Please enter text to translate.',
      );
    }

    // An exact in-memory ML result may return immediately. A miss always
    // continues to the Node.js /api/translate endpoint; the offline dictionary
    // is deliberately never consulted here.
    final key = _cacheKey(trimmed, sourceLanguage, targetLanguage);
    final cached = _cache[key];
    if (cached != null) {
      _debugLog('[TranslationService] ML cache hit');
      return cached;
    }

    final candidateUrls = ApiConfig.candidateBackendUrls;
    final failures = <String>[];
    http.Response? response;
    String? winningBaseUrl;

    _debugLog(
      '[TranslationService] POST /api/translate using '
      '${candidateUrls.length} configured backend URL(s)',
    );

    // Candidates are tried one at a time. This avoids sending duplicate ML
    // inference requests to multiple hosts and lets the first HTTP response
    // classify the failure as model/request rather than network-unavailable.
    for (final baseUrl in candidateUrls) {
      final endpoint = ApiConfig.translateUrlFor(baseUrl);
      _debugLog('[TranslationService] POST $endpoint');
      try {
        final result = await _client
            .post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': trimmed,
                'source_language': sourceLanguage,
                'target_language': targetLanguage,
              }),
            )
            .timeout(ApiConfig.translateTimeout);
        _debugLog(
          '[TranslationService] POST $endpoint -> HTTP ${result.statusCode}',
        );
        response = result;
        winningBaseUrl = baseUrl;
        break;
      } on TimeoutException catch (error) {
        failures.add('$endpoint timeout');
        _debugLog(
          '[TranslationService] POST $endpoint timed out: '
          '${error.runtimeType}',
        );
      } catch (error) {
        // SocketException/connection-refused errors arrive here on native
        // platforms. Do not log the request body or entered user text.
        failures.add('$endpoint ${error.runtimeType}');
        _debugLog(
          '[TranslationService] POST $endpoint connection failed: '
          '${error.runtimeType}: $error',
        );
      }
    }

    if (response == null || winningBaseUrl == null) {
      final technical = failures.isEmpty ? 'no HTTP response' : failures.join('; ');
      _debugLog('[TranslationService] Backend unavailable: $technical');
      throw TranslationApiException(
        kind: TranslationFailureKind.unavailable,
        message:
            'Translation service is currently unavailable. Check that the ML server is running and that this device can reach it.',
        technicalMessage: technical,
      );
    }

    ApiConfig.customBackendBaseUrl = winningBaseUrl;

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      body = decoded;
    } catch (error) {
      _debugLog(
        '[TranslationService] POST ${ApiConfig.translateUrlFor(winningBaseUrl)} '
        'response parsing failed (HTTP ${response.statusCode}, '
        '${response.body.length} bytes): ${error.runtimeType}',
      );
      throw TranslationApiException(
        kind: TranslationFailureKind.response,
        message: 'Translation service returned an unexpected response. Please try again.',
        statusCode: response.statusCode,
        technicalMessage: error.toString(),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final translation = body['translation'];
      if (translation is! String || translation.trim().isEmpty) {
        _debugLog(
          '[TranslationService] Model response missing a non-empty translation '
          '(HTTP ${response.statusCode})',
        );
        throw const TranslationApiException(
          kind: TranslationFailureKind.response,
          message: 'Translation service returned an unexpected response. Please try again.',
        );
      }

      final result = TranslationResult(
        source: trimmed,
        output: translation,
        isPrototype: false,
        matchedPhrase: false,
      );
      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = result;
      _debugLog('[TranslationService] IndicTrans2 translation cached');
      return result;
    }

    final errorValue = body['error'];
    final errorMessage = errorValue is String
        ? errorValue
        : 'Translation failed (HTTP ${response.statusCode}).';
    final errorType = body['error_type'];
    final isUnavailable = errorType == 'unavailable';
    final isModelError = !isUnavailable &&
        (response.statusCode >= 500 || errorType == 'model');
    _debugLog(
      '[TranslationService] ${isUnavailable
          ? 'dependency-unavailable'
          : isModelError
              ? 'ML inference'
              : 'request'} error HTTP ${response.statusCode}: $errorMessage',
    );
    throw TranslationApiException(
      kind: isUnavailable
          ? TranslationFailureKind.unavailable
          : isModelError
              ? TranslationFailureKind.model
              : TranslationFailureKind.request,
      message: isUnavailable
          ? 'Translation service is currently unavailable. Check that the ML server is running and that this device can reach it.'
          : isModelError
              ? 'The translation model could not process this request. Please try again.'
              : 'The translation request could not be processed. Please try again.',
      statusCode: response.statusCode,
      technicalMessage: errorMessage,
    );
  }

  void _debugLog(String message) {
    if (kDebugMode) dev.log(message, name: 'TranslationService');
  }

  // ── Sync mock helpers — delegate to MockTranslationService ────────────────
  //
  // These are called ONLY by phrase-tiles (synchronous quick-fill).
  // They use the offline dictionary and are NOT a translation fallback.

  @override
  TranslationResult hindiToSantali(String input) =>
      MockTranslationService.instance.hindiToSantali(input);

  @override
  TranslationResult santaliToHindi(String input) =>
      MockTranslationService.instance.santaliToHindi(input);
}

// ── Mock / dictionary service (phrase-tiles & legacy) ─────────────────────────
//
// This class is kept intact so:
//   1. Phrase-tiles still show quick Santali translations without network.
//   2. on_device_services.dart (OnDeviceTranslationService) still compiles.
//   3. Tests that depend on MockTranslationService continue to work.
//
// It is NOT the active TranslationService.instance.
// The Translate button always calls ApiTranslationService.translate().

class MockTranslationService implements TranslationService {
  MockTranslationService._();
  static final MockTranslationService instance = MockTranslationService._();

  static const List<ClassroomPhrase> phrases = [
    ClassroomPhrase(
      id: 'count-objects',
      hindi: 'बच्चों को दस वस्तुएँ दें और उन्हें एक-एक करके गिनने के लिए कहें।',
      santali: 'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱜᱮᱞ ᱜᱚᱴᱟᱝ ᱡᱤᱱᱤᱥ ᱮᱢᱟ ᱠᱚᱢ ᱟᱨ ᱢᱤᱫ-ᱢᱤᱫ ᱛᱮ ᱞᱮᱠᱷᱟ ᱪᱚ ᱠᱚᱢ᱾',
      englishHint: 'Give ten objects and ask children to count one by one.',
    ),
    ClassroomPhrase(
      id: 'open-book',
      hindi: 'बच्चों को अपनी किताब खोलने के लिए कहें।',
      santali: 'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱟᱠᱚᱣᱟᱜ ᱯᱚᱛᱚᱵ ᱠᱷᱩᱞᱟᱹᱣ ᱞᱟᱹᱜᱤᱫ ᱢᱮᱛᱟ ᱠᱚᱢ᱾',
      englishHint: 'Ask children to open their book.',
    ),
    ClassroomPhrase(
      id: 'ask-addition',
      hindi: 'दो और दो कितने होते हैं, बच्चों से पूछें।',
      santali: 'ᱵᱟᱨ ᱟᱨ ᱵᱟᱨ ᱛᱤᱱᱟᱹᱜ ᱦᱩᱭᱩᱜᱼᱟ, ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱠᱩᱞᱤ ᱠᱚᱢ᱾',
      englishHint: 'Ask children how much is two and two.',
    ),
    ClassroomPhrase(
      id: 'repeat-sentence',
      hindi: 'एक वाक्य बोलें और बच्चों से दोहराने को कहें।',
      santali: 'ᱢᱤᱫ ᱟᱹᱭᱠᱟᱹᱣ ᱢᱮ ᱟᱨ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱫᱩᱦᱲᱟᱹ ᱞᱟᱹᱜᱤᱫ ᱢᱮᱛᱟ ᱠᱚᱢ᱾',
      englishHint: 'Say a sentence and ask children to repeat.',
    ),
    ClassroomPhrase(
      id: 'sit-quietly',
      hindi: 'शांत बैठो।',
      santali: 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾',
      englishHint: 'Sit quietly.',
    ),
    ClassroomPhrase(
      id: 'listen-carefully',
      hindi: 'कृपया ध्यान से सुनो।',
      santali: 'ᱫᱟᱭᱟᱠᱟᱛᱮ ᱜᱚᱨ ᱥᱟᱶ ᱟᱸᱡᱚᱢ ᱯᱮ᱾',
      englishHint: 'Please listen carefully.',
    ),
    ClassroomPhrase(
      id: 'open-notebook',
      hindi: 'अपनी कॉपी खोलो।',
      santali: 'ᱟᱢᱟᱜ ᱠᱚᱯᱤ ᱠᱷᱩᱞᱟᱹᱣ ᱯᱮ᱾',
      englishHint: 'Open your notebook.',
    ),
    ClassroomPhrase(
      id: 'how-many',
      hindi: 'यह कितने हैं?',
      santali: 'ᱱᱚᱣᱟ ᱛᱤᱱᱟᱹᱜ ᱢᱮᱱᱟᱜᱼᱟ?',
      englishHint: 'How many are these?',
    ),
    ClassroomPhrase(
      id: 'very-good',
      hindi: 'बहुत अच्छा।',
      santali: 'ᱟᱹᱰᱤ ᱵᱟᱹᱲᱤᱡᱽ᱾',
      englishHint: 'Very good.',
    ),
    ClassroomPhrase(
      id: 'count-together',
      hindi: 'अब मिलकर गिनो।',
      santali: 'ᱱᱤᱛᱚᱜ ᱢᱤᱫ ᱥᱟᱶᱛᱮ ᱞᱮᱠᱷᱟ ᱯᱮ᱾',
      englishHint: 'Now count together.',
    ),
  ];

  static const Map<String, String> _hindiToSantaliWords = {
    'बच्चों': 'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ',
    'किताब': 'ᱯᱚᱛᱚᱵ',
    'कॉपी': 'ᱠᱚᱯᱤ',
    'गिनो': 'ᱞᱮᱠᱷᱟ',
    'गिनने': 'ᱞᱮᱠᱷᱟ',
    'खोलो': 'ᱠᱷᱩᱞᱟᱹᱣ',
    'सुनो': 'ᱟᱸᱡᱚᱢ',
    'बैठो': 'ᱫᱩᱲᱩᱵ',
    'दो': 'ᱵᱟᱨ',
    'दस': 'ᱜᱮᱞ',
    'एक': 'ᱢᱤᱫ',
    'कितने': 'ᱛᱤᱱᱟᱹᱜ',
    'अच्छा': 'ᱵᱟᱹᱲᱤᱡᱽ',
  };

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // The mock does not call a network service — delegate to sync helpers.
    if (sourceLanguage == 'hin_Deva') return hindiToSantali(text);
    return santaliToHindi(text);
  }

  @override
  TranslationResult hindiToSantali(String input) {
    final source = input.trim();
    if (source.isEmpty) {
      return const TranslationResult(
        source: '',
        output: '',
        isPrototype: true,
        matchedPhrase: false,
        note: 'Type a Hindi classroom phrase to translate.',
      );
    }
    final exact = _findPhrase(source);
    if (exact != null) {
      return TranslationResult(
        source: source,
        output: exact.santali,
        isPrototype: true,
        matchedPhrase: true,
        note: exact.englishHint,
      );
    }
    final words = source.split(RegExp(r'\s+'));
    final translated = <String>[];
    var anyHit = false;
    for (final word in words) {
      final k = word.replaceAll(RegExp(r'[।?!,.]'), '');
      final mapped = _hindiToSantaliWords[k];
      if (mapped != null) {
        anyHit = true;
        translated.add(mapped);
      } else {
        translated.add(word);
      }
    }
    return TranslationResult(
      source: source,
      output: translated.join(' '),
      isPrototype: true,
      matchedPhrase: false,
      note: anyHit
          ? 'Partial word-level match (phrase-tile preview).'
          : 'No offline match — phrase-tile preview only.',
    );
  }

  @override
  TranslationResult santaliToHindi(String input) {
    final source = input.trim();
    if (source.isEmpty) {
      return const TranslationResult(
        source: '',
        output: '',
        isPrototype: true,
        matchedPhrase: false,
        note: 'Paste Ol Chiki text from a known classroom phrase.',
      );
    }
    for (final phrase in phrases) {
      if (_normalize(phrase.santali) == _normalize(source)) {
        return TranslationResult(
          source: source,
          output: phrase.hindi,
          isPrototype: true,
          matchedPhrase: true,
          note: phrase.englishHint,
        );
      }
    }
    return TranslationResult(
      source: source,
      output: source,
      isPrototype: true,
      matchedPhrase: false,
      note: 'No offline match — phrase-tile preview only.',
    );
  }

  ClassroomPhrase? _findPhrase(String source) {
    final needle = _normalize(source);
    for (final phrase in phrases) {
      if (_normalize(phrase.hindi) == needle) return phrase;
    }
    ClassroomPhrase? best;
    for (final phrase in phrases) {
      final hindi = _normalize(phrase.hindi);
      if (needle.contains(hindi) || hindi.contains(needle)) {
        if (best == null || phrase.hindi.length > best.hindi.length) {
          best = phrase;
        }
      }
    }
    return best;
  }

  String _normalize(String value) {
    return value
        .replaceAll('[Prototype Santali Translation]', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('।', '')
        .trim();
  }
}
