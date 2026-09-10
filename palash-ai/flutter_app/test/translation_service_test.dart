import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_app/core/api_config.dart';
import 'package:flutter_app/services/translation_service.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

http.StreamedResponse _jsonResponse(
  http.BaseRequest request,
  int statusCode,
  Map<String, Object?> body,
) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
    statusCode,
    headers: const {'content-type': 'application/json'},
    request: request,
  );
}

void main() {
  setUp(() {
    ApiConfig.customBackendBaseUrl = 'http://192.0.2.10:3000';
  });

  tearDown(() {
    ApiConfig.customBackendBaseUrl = null;
  });

  test('cache miss posts to ML endpoint and never uses dictionary output', () async {
    final client = _FakeHttpClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://192.0.2.10:3000/api/translate');
      return _jsonResponse(request, 200, const {
        'success': true,
        'input': 'एक बिल्कुल नया शब्द',
        'translation': 'ᱢᱤᱫ ᱱᱟᱣᱟ ᱚᱞ',
        'source_language': 'hin_Deva',
        'target_language': 'sat_Olck',
      });
    });

    final result = await ApiTranslationService(client: client).translate(
      text: 'एक बिल्कुल नया शब्द',
      sourceLanguage: 'hin_Deva',
      targetLanguage: 'sat_Olck',
    );

    expect(client.requests, hasLength(1));
    expect(result.output, 'ᱢᱤᱫ ᱱᱟᱣᱟ ᱚᱞ');
    expect(result.isPrototype, isFalse);
    expect(result.matchedPhrase, isFalse);
  });

  test('upstream unavailable response becomes retryable unavailable failure', () async {
    final client = _FakeHttpClient((request) async {
      return _jsonResponse(request, 503, const {
        'success': false,
        'error': 'Python translation service is unreachable.',
        'error_type': 'unavailable',
      });
    });

    try {
      await ApiTranslationService(client: client).translate(
        text: 'नमस्ते',
        sourceLanguage: 'hin_Deva',
        targetLanguage: 'sat_Olck',
      );
      fail('Expected TranslationApiException');
    } on TranslationApiException catch (error) {
      expect(error.kind, TranslationFailureKind.unavailable);
      expect(
        error.message,
        'Translation service is currently unavailable. Check that the ML server is running and that this device can reach it.',
      );
    }
  });

  test('reachable model failure is distinguished from a network failure', () async {
    final client = _FakeHttpClient((request) async {
      return _jsonResponse(request, 502, const {
        'success': false,
        'error': 'Translation failed. Please try again.',
        'error_type': 'model',
      });
    });

    try {
      await ApiTranslationService(client: client).translate(
        text: 'नया वाक्य',
        sourceLanguage: 'hin_Deva',
        targetLanguage: 'sat_Olck',
      );
      fail('Expected TranslationApiException');
    } on TranslationApiException catch (error) {
      expect(error.kind, TranslationFailureKind.model);
      expect(
        error.message,
        'The translation model could not process this request. Please try again.',
      );
    }
  });

  test('connection refusal is classified as unavailable', () async {
    final client = _FakeHttpClient((request) async {
      throw const SocketException('Connection refused');
    });

    try {
      await ApiTranslationService(client: client).translate(
        text: 'नमस्ते',
        sourceLanguage: 'hin_Deva',
        targetLanguage: 'sat_Olck',
      );
      fail('Expected TranslationApiException');
    } on TranslationApiException catch (error) {
      expect(error.kind, TranslationFailureKind.unavailable);
    }
  });

  group('normalizeTranslationInput', () {
    test('normalizes Hindi variations to exact same string with danda', () {
      expect(normalizeTranslationInput('शांत बैठो', 'hin_Deva'), 'शांत बैठो।');
      expect(normalizeTranslationInput('शांत बैठो।', 'hin_Deva'), 'शांत बैठो।');
      expect(normalizeTranslationInput('शांत बैठो.', 'hin_Deva'), 'शांत बैठो।');
      expect(normalizeTranslationInput('  शांत   बैठो   ', 'hin_Deva'), 'शांत बैठो।');
      expect(normalizeTranslationInput('यह कितने हैं?', 'hin_Deva'), 'यह कितने हैं?');
      expect(normalizeTranslationInput('सावधान!', 'hin_Deva'), 'सावधान!');
    });

    test('normalizes Santali variations to exact same string with Mu Tudag', () {
      expect(normalizeTranslationInput('ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ', 'sat_Olck'), 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾');
      expect(normalizeTranslationInput('ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾', 'sat_Olck'), 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾');
      expect(normalizeTranslationInput('ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ.', 'sat_Olck'), 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾');
      expect(normalizeTranslationInput('  ᱥᱟᱱᱛᱤ  ᱛᱮ  ᱫᱩᱲᱩᱵ  ᱯᱮ  ', 'sat_Olck'), 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾');
      expect(normalizeTranslationInput('ᱱᱚᱣᱟ ᱛᱤᱱᱟᱹᱜ ᱢᱮᱱᱟᱜᱼᱟ?', 'sat_Olck'), 'ᱱᱚᱣᱟ ᱛᱤᱱᱟᱹᱜ ᱢᱮᱱᱟᱜᱼᱟ?');
    });
  });

  test('translating "शांत बैठो" and "शांत बैठो।" results in cache hit and identical output', () async {
    final client = _FakeHttpClient((request) async {
      final body = jsonDecode((request as http.Request).body);
      expect(body['text'], 'शांत बैठो।');
      return _jsonResponse(request, 200, const {
        'success': true,
        'input': 'शांत बैठो।',
        'translation': 'ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾',
        'source_language': 'hin_Deva',
        'target_language': 'sat_Olck',
        'model': 'ai4bharat/indictrans2-indic-indic-dist-320M',
      });
    });

    final service = ApiTranslationService(client: client);

    // Call 1: Without danda
    final result1 = await service.translate(
      text: 'शांत बैठो',
      sourceLanguage: 'hin_Deva',
      targetLanguage: 'sat_Olck',
    );

    // Call 2: With danda — must hit cache, no second HTTP request!
    final result2 = await service.translate(
      text: 'शांत बैठो।',
      sourceLanguage: 'hin_Deva',
      targetLanguage: 'sat_Olck',
    );

    // Call 3: With ASCII period — must also hit cache!
    final result3 = await service.translate(
      text: 'शांत बैठो.',
      sourceLanguage: 'hin_Deva',
      targetLanguage: 'sat_Olck',
    );

    expect(client.requests, hasLength(1), reason: 'All variations must hit cache after first request');
    expect(result1.output, 'ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾');
    expect(result2.output, 'ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾');
    expect(result3.output, 'ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾');
    expect(result1.model, 'ai4bharat/indictrans2-indic-indic-dist-320M');
    expect(result2.model, 'ai4bharat/indictrans2-indic-indic-dist-320M');
    expect(result3.model, 'ai4bharat/indictrans2-indic-indic-dist-320M');
  });
}
