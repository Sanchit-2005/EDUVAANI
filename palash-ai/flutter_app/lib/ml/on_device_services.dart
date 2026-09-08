import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart';

import '../core/api_config.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/translation_service.dart';
import 'model_manager.dart';

/// ONNX-ready adapter boundaries. Inference is intentionally unavailable until
/// validated, quantized model files are placed in the model manager location.
///
/// On-device inference only exists as a native Android host
/// (android/.../ml/OnDeviceTranslationEngine.kt) reached via MethodChannel.
/// There is no browser/WASM runtime and no ONNX bundle exported for web.
/// Calling `_channel.invokeMethod(...)` on web throws a MissingPluginException
/// — an internal plumbing error, not a description of the real problem — so
/// every on-device entry point below checks the platform FIRST and fails
/// with an explicit, typed [TranslationApiException]
/// (kind: unsupportedPlatform) before it ever reaches the channel.
class _NoOnDeviceRuntimeError extends TranslationApiException {
  const _NoOnDeviceRuntimeError(String feature)
      : super(
          kind: TranslationFailureKind.unsupportedPlatform,
          message:
              '$feature runs on-device only in the Android app. This build '
              '(web) has no native model runtime or ONNX bundle for it — '
              'switch off "On-device" here, or use the Android app.',
        );
}

class OnDeviceASRService implements SpeechRecognitionService {
  OnDeviceASRService({ModelManager? manager}) : _manager = manager ?? ModelManager();
  final ModelManager _manager;

  @override
  Future<SpeechRecognitionResult> transcribeHindi(String audioPath) async {
    if (kIsWeb) throw const _NoOnDeviceRuntimeError('On-device Hindi ASR');
    await _manager.requireModel(ModelManager.hindiAsr);
    throw UnsupportedError('Hindi ONNX ASR inference is not bundled in this prototype.');
  }
}

class OnDeviceTranslationService implements TranslationService {
  OnDeviceTranslationService({ModelManager? manager}) : _manager = manager ?? ModelManager();
  final ModelManager _manager;

  static const MethodChannel _channel = MethodChannel('eduvaani/on_device_translation');

  Future<void> ensureModelReady() async {
    if (kIsWeb) throw const _NoOnDeviceRuntimeError('On-device translation');
    await _manager.requireModel(ModelManager.hindiSantaliTranslation);
  }

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

    // Fail explicitly before touching the MethodChannel: web has no native
    // host and no ONNX bundle for this feature. Without this check, the
    // channel call below throws MissingPluginException, which the generic
    // catch (error) block reports as a misleading "unexpected response".
    if (kIsWeb) {
      throw const _NoOnDeviceRuntimeError('On-device translation');
    }

    try {
      // The native translate handler initializes the engine itself (idempotent).
      // Do NOT call 'initialize' separately here — it adds an extra blocking
      // round-trip for every request and was the main cause of UI freezes.
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
    } on MissingPluginException catch (error) {
      // No handler registered for this channel on this platform/build — the
      // native engine isn't wired up here. This is a runtime-availability
      // gap, not a model or response failure, so it gets its own explicit kind
      // rather than falling into the generic catch-all below.
      _debugLog('[OnDeviceTranslationService] MissingPluginException: $error');
      throw const _NoOnDeviceRuntimeError('On-device translation');
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
    if (kIsWeb) throw const _NoOnDeviceRuntimeError('On-device Santali TTS');
    await _manager.requireModel(ModelManager.santaliTts);
    throw UnsupportedError('Santali ONNX TTS inference is not bundled in this prototype.');
  }
}