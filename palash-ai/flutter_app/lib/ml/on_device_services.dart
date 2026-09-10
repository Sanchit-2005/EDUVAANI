import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/translation_service.dart';
import 'asr_fuzzy_matcher.dart';
import 'asr_session_logger.dart';
import 'model_manager.dart';
import 'santali_phoneme_map.dart';

bool _sherpaBindingsInitialized = false;
void _initSherpaBindings() {
  if (!_sherpaBindingsInitialized) {
    try {
      debugPrint('[SherpaBindings] Initializing sherpa bindings...');
      if (!kIsWeb && Platform.isAndroid) {
        try {
          DynamicLibrary.open('libonnxruntime.so');
          debugPrint('[SherpaBindings] Successfully opened libonnxruntime.so in Dart');
        } catch (e) {
          debugPrint('[SherpaBindings] Warning opening libonnxruntime.so: $e');
        }
      }
      sherpa.initBindings();
      _sherpaBindingsInitialized = true;
      debugPrint('[SherpaBindings] Successfully initialized sherpa bindings!');
    } catch (e, st) {
      debugPrint('[SherpaBindings] Error initializing sherpa bindings: $e\n$st');
      rethrow;
    }
  }
}

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
  OnDeviceASRService({ModelManager? manager, ClassroomCommandFuzzyMatcher? fuzzyMatcher})
      : _manager = manager ?? ModelManager(),
        _fuzzyMatcher = fuzzyMatcher ?? ClassroomCommandFuzzyMatcher();
  final ModelManager _manager;
  final ClassroomCommandFuzzyMatcher _fuzzyMatcher;

  sherpa.OfflineRecognizer? _recognizer;
  AsrModelPaths? _loadedModel;
  AsrModelPaths? get loadedModel => _loadedModel;

  Future<bool> isModelAvailable() async => _manager.isAsrReady();

  Future<void> _ensureRecognizer() async {
    if (kIsWeb) return;
    if (_recognizer != null) return;

    final paths = await _manager.findAsrModel();
    if (paths == null) return;

    try {
      _initSherpaBindings();
      final sherpa.OfflineModelConfig modelConfig;

      if (paths.type == AsrModelType.whisper) {
        modelConfig = sherpa.OfflineModelConfig(
          tokens: paths.tokensPath,
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: paths.encoderPath!,
            decoder: paths.decoderPath!,
            language: 'hi',
            task: 'transcribe',
          ),
          modelType: 'whisper',
          numThreads: 2,
          debug: false,
        );
      } else if (paths.type == AsrModelType.senseVoice) {
        modelConfig = sherpa.OfflineModelConfig(
          tokens: paths.tokensPath,
          senseVoice: sherpa.OfflineSenseVoiceModelConfig(
            model: paths.modelPath!,
            language: 'hi',
            useInverseTextNormalization: true,
          ),
          numThreads: 2,
          debug: false,
        );
      } else {
        modelConfig = sherpa.OfflineModelConfig(
          tokens: paths.tokensPath,
          nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(
            model: paths.modelPath!,
          ),
          numThreads: 2,
          debug: false,
        );
      }

      final feat = sherpa.FeatureConfig(sampleRate: 16000, featureDim: 80);
      final config = sherpa.OfflineRecognizerConfig(feat: feat, model: modelConfig);
      _recognizer = sherpa.OfflineRecognizer(config);
      _loadedModel = paths;
      _debugLog('[OnDeviceASRService] Successfully loaded ${paths.type} model');
    } catch (e) {
      _debugLog('[OnDeviceASRService] Failed to initialize recognizer: $e');
      _recognizer = null;
    }
  }

  @override
  Future<SpeechRecognitionResult> transcribeHindi(
    String audioPath, {
    String? demoTranscript,
  }) async {
    final sw = Stopwatch()..start();
    if (kIsWeb) throw const _NoOnDeviceRuntimeError('On-device Hindi ASR');

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw StateError('The recording could not be found at $audioPath');
    }

    await _ensureRecognizer();

    if (_recognizer != null) {
      try {
        final wave = sherpa.readWave(audioPath);
        final rawSamples = wave.samples;
        
        // Apply 300ms silence padding (at wave.sampleRate) universally to prevent
        // short-utterance edge-frame truncation on CTC feature extraction.
        final paddingLen = (wave.sampleRate * 0.3).round();
        final paddedSamples = Float32List(rawSamples.length + paddingLen * 2);
        paddedSamples.setRange(paddingLen, paddingLen + rawSamples.length, rawSamples);

        final stream = _recognizer!.createStream();
        stream.acceptWaveform(samples: paddedSamples, sampleRate: wave.sampleRate);
        _recognizer!.decode(stream);
        final result = _recognizer!.getResult(stream);
        stream.free();
        sw.stop();

        // ── Fuzzy post-processing ───────────────────────────────────────
        final rawText = result.text.trim();
        final matchResult = _fuzzyMatcher.matchCommand(rawText);

        // Log raw + corrected for every session (never discard the raw signal).
        AsrSessionLogger.instance.log(
          rawTranscript: matchResult.rawTranscript,
          correctedTranscript: matchResult.correctedTranscript,
          wasMatchApplied: matchResult.wasMatchApplied,
          similarityScore: matchResult.similarityScore,
          matchedCommand: matchResult.matchedCommand,
        );

        return SpeechRecognitionResult(
          transcript: matchResult.correctedTranscript,
          rawTranscript: matchResult.rawTranscript,
          duration: sw.elapsed,
          isMock: false,
        );
      } catch (e) {
        _debugLog('[OnDeviceASRService] Sherpa inference failed: $e');
        if (demoTranscript != null) {
          sw.stop();
          return SpeechRecognitionResult(
            transcript: demoTranscript,
            duration: sw.elapsed,
            isMock: true,
          );
        }
        rethrow;
      }
    }

    if (demoTranscript != null) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      sw.stop();
      return SpeechRecognitionResult(
        transcript: demoTranscript,
        duration: sw.elapsed,
        isMock: true,
      );
    }

    throw const ModelUnavailableException(ModelManager.hindiAsr);
  }

  void dispose() {
    _recognizer?.free();
    _recognizer = null;
  }

  void _debugLog(String message) {
    if (kDebugMode) dev.log(message, name: 'OnDeviceASRService');
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
    final normalized = normalizeTranslationInput(text, sourceLanguage);
    if (normalized.isEmpty) {
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
          'text': normalized,
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
        source: normalized,
        output: translation,
        isPrototype: false,
        matchedPhrase: false,
        model: 'ai4bharat/indictrans2-indic-indic-dist-320M (On-Device)',
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

  final Map<String, sherpa.OfflineTts> _ttsEngines = {};
  final Map<String, TtsModelPaths> _loadedModels = {};

  TtsModelPaths? get loadedModel => _loadedModels.values.firstOrNull;

  Future<bool> isModelAvailable() async => _manager.isTtsReady();
  Future<bool> isMaleModelAvailable() async => _manager.isTtsMaleReady();
  Future<bool> isFemaleModelAvailable() async => _manager.isTtsFemaleReady();

  Future<sherpa.OfflineTts?> _ensureTtsForGender(String gender) async {
    if (kIsWeb) return null;
    final cached = _ttsEngines[gender];
    if (cached != null) return cached;

    // Look for gender-specific model, fallback to any available model
    var paths = await _manager.findTtsModel(gender: gender);
    if (paths == null && gender == 'male') {
      // Specifically requested male model but not found
      return null;
    }
    paths ??= await _manager.findTtsModel();
    if (paths == null) return null;

    try {
      _initSherpaBindings();
      _debugLog('[OnDeviceTTSService] Initializing OfflineTts ($gender) with model: ${paths.modelPath}, tokens: ${paths.tokensPath}, dataDir: ${paths.dataDirPath}');
      final vits = sherpa.OfflineTtsVitsModelConfig(
        model: paths.modelPath,
        tokens: paths.tokensPath,
        dataDir: paths.dataDirPath ?? '',
        lexicon: paths.lexiconPath ?? '',
      );
      final model = sherpa.OfflineTtsModelConfig(
        vits: vits,
        numThreads: 2,
        debug: false,
      );
      final config = sherpa.OfflineTtsConfig(model: model);
      final engine = sherpa.OfflineTts(config);
      _ttsEngines[gender] = engine;
      _loadedModels[gender] = paths;
      _debugLog('[OnDeviceTTSService] Loaded TTS model for $gender from ${paths.modelPath}');
      return engine;
    } catch (e, st) {
      _debugLog('[OnDeviceTTSService] Failed to initialize TTS for $gender: $e\n$st');
      return null;
    }
  }

  @override
  Future<TextToSpeechResult> synthesizeSantali(
    String text, {
    int speakerId = 0,
    String? gender,
    double speed = 1.0,
    bool fallbackToDemo = true,
  }) async {
    final sw = Stopwatch()..start();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Santali text cannot be empty.');
    }

    // Determine target voice gender: 0 = female (Priyamvada), 1 = male (Rohan)
    final targetGender = gender != null
        ? gender.toLowerCase().trim()
        : (speakerId == 1 ? 'male' : 'female');

    // Option A: Phonetic fallback from Santali (Ol Chiki) to Hindi Devanagari phonemes
    final phonemes = santaliToHindiPhonemes(trimmed);
    _debugLog('Transliterated Ol Chiki "$trimmed" -> Devanagari phonemes "$phonemes" ($targetGender)');

    if (kIsWeb) {
      if (fallbackToDemo) {
        return MockTextToSpeechService().synthesizeSantali(trimmed);
      }
      throw const _NoOnDeviceRuntimeError('On-device Santali TTS');
    }

    final engine = await _ensureTtsForGender(targetGender);
    _debugLog('[OnDeviceTTSService] _ensureTtsForGender($targetGender) complete. engine is null? ${engine == null}');

    if (engine != null) {
      try {
        _debugLog('[OnDeviceTTSService] Generating audio for "$phonemes", gender: $targetGender, sid: 0');
        // Note: single-speaker Piper models require sid: 0
        final audio = engine.generate(
          text: phonemes,
          sid: 0,
          speed: speed,
        );
        _debugLog('[OnDeviceTTSService] Generated ${audio.samples.length} samples at ${audio.sampleRate}Hz');

        final directory = await _getTempDir();
        final outPath = p.join(
          directory.path,
          'eduvaani_santali_${trimmed.hashCode.abs()}_${targetGender}_sid$speakerId.wav',
        );

        sherpa.writeWave(
          filename: outPath,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        );
        _debugLog('[OnDeviceTTSService] Wrote wave to $outPath');
        sw.stop();
        return TextToSpeechResult(
          audioPath: outPath,
          duration: sw.elapsed,
          isMock: false,
        );
      } catch (e, st) {
        _debugLog('[OnDeviceTTSService] Sherpa TTS generation error: $e\n$st');
        if (fallbackToDemo) {
          return MockTextToSpeechService().synthesizeSantali(trimmed);
        }
        rethrow;
      }
    }

    if (fallbackToDemo) {
      return MockTextToSpeechService().synthesizeSantali(trimmed);
    }

    throw const ModelUnavailableException(ModelManager.santaliTts);
  }

  Future<Directory> _getTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  void dispose() {
    for (final engine in _ttsEngines.values) {
      engine.free();
    }
    _ttsEngines.clear();
    _loadedModels.clear();
  }

  void _debugLog(String message) {
    debugPrint(message);
    if (kDebugMode) dev.log(message, name: 'OnDeviceTTSService');
  }
}