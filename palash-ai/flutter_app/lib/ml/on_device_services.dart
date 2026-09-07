import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

import '../core/api_config.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/translation_service.dart';
import 'model_manager.dart';

/// ONNX-ready adapter boundaries. Inference is intentionally unavailable until
/// validated, quantized model files are placed in the model manager location.
class OnDeviceASRService implements SpeechRecognitionService {
  OnDeviceASRService({ModelManager? manager}) : _manager = manager ?? ModelManager();
  final ModelManager _manager;

  @override
  Future<SpeechRecognitionResult> transcribeHindi(String audioPath) async {
    await _manager.requireModel(ModelManager.hindiAsr);
    throw UnsupportedError('Hindi ONNX ASR inference is not bundled in this prototype.');
  }
}

class OnDeviceTranslationService implements TranslationService {
  OnDeviceTranslationService({ModelManager? manager}) : _manager = manager ?? ModelManager();
  final ModelManager _manager;

  static const MethodChannel _channel = MethodChannel('eduvaani/on_device_translation');

  Future<void> ensureModelReady() async =>
      _manager.requireModel(ModelManager.hindiSantaliTranslation);

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

    try {
      // First, try to initialize the engine explicitly
      try {
        final initResult = await _channel.invokeMethod('initialize');
        _debugLog('[OnDeviceTranslationService] Initialize result: $initResult');
      } catch (e, stack) {
        _debugLog('[OnDeviceTranslationService] Initialize error: $e, stack: $stack');
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'translate',
        {
          'text': trimmed,
          'source_lang': sourceLanguage,
          'target_lang': targetLanguage,
        },
      );

      if (result == null) {
        throw const TranslationApiException(
          kind: TranslationFailureKind.response,
          message: 'On-device translation returned an empty response.',
        );
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw TranslationApiException(
          kind: TranslationFailureKind.model,
          message: 'On-device translation failed.',
          technicalMessage: result['error']?.toString(),
        );
      }

      final translation = result['translation'] as String? ?? '';
      if (translation.trim().isEmpty) {
        throw const TranslationApiException(
          kind: TranslationFailureKind.response,
          message: 'On-device translation returned an empty result.',
        );
      }

      return TranslationResult(
        source: trimmed,
        output: translation,
        isPrototype: false,
        matchedPhrase: false,
      );
    } on PlatformException catch (error) {
      _debugLog('[OnDeviceTranslationService] PlatformException: ${error.code} - ${error.message}');
      _debugLog('[OnDeviceTranslationService] PlatformException details: ${error.details}');
      throw TranslationApiException(
        kind: TranslationFailureKind.unavailable,
        message: 'On-device translation is not available: ${error.message}',
        technicalMessage: error.details?.toString(),
      );
    } catch (error, stack) {
      _debugLog('[OnDeviceTranslationService] Unexpected error: $error, stack: $stack');
      throw TranslationApiException(
        kind: TranslationFailureKind.model,
        message: 'On-device translation failed unexpectedly.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  TranslationResult hindiToSantali(String input) {
    throw UnsupportedError(
      'On-device hindiToSantali synchronous fallback is not supported. Use translate() instead.',
    );
  }

  @override
  TranslationResult santaliToHindi(String input) {
    throw UnsupportedError(
      'On-device santaliToHindi synchronous fallback is not supported. Use translate() instead.',
    );
  }

  void _debugLog(String message) {
    if (kDebugMode) dev.log(message, name: 'OnDeviceTranslationService');
  }
}

class OnDeviceTTSService implements TextToSpeechService {
  OnDeviceTTSService({ModelManager? manager}) : _manager = manager ?? ModelManager();
  final ModelManager _manager;

  @override
  Future<TextToSpeechResult> synthesizeSantali(String text) async {
    await _manager.requireModel(ModelManager.santaliTts);
    throw UnsupportedError('Santali ONNX TTS inference is not bundled in this prototype.');
  }
}