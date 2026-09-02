import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ModelStatus { missing, downloaded, loaded }

class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.label,
    required this.fileName,
    required this.version,
  });

  final String id;
  final String label;
  final String fileName;
  final String version;
}

class ModelUnavailableException implements Exception {
  const ModelUnavailableException(this.model);
  final ModelDescriptor model;

  @override
  String toString() => '${model.label} has not been downloaded yet.';
}

/// Manages model files without loading every model into memory at once.
class ModelManager {
  static const hindiAsr = ModelDescriptor(
    id: 'hindi_asr', label: 'Hindi ASR', fileName: 'hindi_asr_int8.onnx', version: 'prototype',
  );
  static const hindiSantaliTranslation = ModelDescriptor(
    id: 'hindi_santali_translation', label: 'Hindi to Santali', fileName: 'hindi_santali_int8.onnx', version: 'prototype',
  );
  static const santaliTts = ModelDescriptor(
    id: 'santali_tts', label: 'Santali TTS', fileName: 'santali_tts_int8.onnx', version: 'prototype',
  );

  Future<File> modelFile(ModelDescriptor model) async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'models', model.fileName));
  }

  Future<ModelStatus> status(ModelDescriptor model) async {
    final file = await modelFile(model);
    return file.exists() ? ModelStatus.downloaded : ModelStatus.missing;
  }

  Future<File> requireModel(ModelDescriptor model) async {
    final file = await modelFile(model);
    if (!await file.exists()) throw ModelUnavailableException(model);
    return file;
  }
}
