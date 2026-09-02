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

  Future<void> ensureModelReady() async => _manager.requireModel(ModelManager.hindiSantaliTranslation);

  @override
  TranslationResult hindiToSantali(String input) => throw UnsupportedError(
    'Hindi to Santali ONNX inference is not bundled in this prototype.',
  );

  @override
  TranslationResult santaliToHindi(String input) => throw UnsupportedError(
    'Santali to Hindi ONNX inference is not bundled in this prototype.',
  );
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
