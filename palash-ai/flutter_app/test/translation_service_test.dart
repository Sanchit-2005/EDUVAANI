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
}
