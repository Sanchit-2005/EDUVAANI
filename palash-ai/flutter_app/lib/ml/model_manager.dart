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
    id: 'hindi_asr',
    label: 'Hindi ASR',
    fileName: 'hindi_asr_int8.onnx',
    version: 'prototype',
  );
  static const hindiSantaliTranslation = ModelDescriptor(
    id: 'hindi_santali_translation',
    label: 'Hindi to Santali',
    fileName: 'hindi_santali_int8.onnx',
    version: 'prototype',
  );
  static const santaliTts = ModelDescriptor(
    id: 'santali_tts',
    label: 'Santali TTS',
    fileName: 'santali_tts_int8.onnx',
    version: 'prototype',
  );
  static const olChikiOcr = ModelDescriptor(
    id: 'ol_chiki_ocr',
    label: 'Ol Chiki OCR',
    fileName: 'ol_chiki_ocr_int8.onnx',
    version: 'prototype',
  );
  static const santaliHindiTranslation = ModelDescriptor(
    id: 'santali_hindi_translation',
    label: 'Santali to Hindi',
    fileName: 'santali_hindi_int8.onnx',
    version: 'prototype',
  );
  static const hindiTts = ModelDescriptor(
    id: 'hindi_tts',
    label: 'Hindi TTS',
    fileName: 'hindi_tts_int8.onnx',
    version: 'prototype',
  );

  Future<Directory> modelsDirectory() async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final internal = Directory(p.join(appSupport.path, 'models'));
      if (await internal.exists()) return internal;

      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final externalModels = Directory(p.join(ext.path, 'models'));
        if (await externalModels.exists()) return externalModels;
      }
      return internal;
    } catch (_) {
      return Directory(p.join(Directory.systemTemp.path, 'eduvaani_models'));
    }
  }

  Future<File> modelFile(ModelDescriptor model) async {
    final directory = await modelsDirectory();
    return File(p.join(directory.path, model.fileName));
  }

  Future<ModelStatus> status(ModelDescriptor model) async {
    final file = await modelFile(model);
    final exists = await file.exists();
    return exists ? ModelStatus.downloaded : ModelStatus.missing;
  }

  Future<File> requireModel(ModelDescriptor model) async {
    final file = await modelFile(model);
    if (!await file.exists()) throw ModelUnavailableException(model);
    return file;
  }

  /// Locates installed Hindi ASR model files.
  ///
  /// Searches `<modelsDir>/asr/`, `<modelsDir>/asr-hindi/`, `<modelsDir>/hindi_asr/`,
  /// and `<modelsDir>/` for Whisper, SenseVoice, or CTC ONNX model artifacts.
  Future<AsrModelPaths?> findAsrModel() async {
    final baseDir = await modelsDirectory();
    final List<Directory> candidateDirs = [
      Directory(p.join(baseDir.path, 'asr')),
      Directory(p.join(baseDir.path, 'asr-hindi')),
      Directory(p.join(baseDir.path, 'hindi_asr')),
      baseDir,
    ];

    try {
      candidateDirs.add(Directory('/sdcard/Download/eduvaani_models/asr'));
      candidateDirs.add(Directory('/sdcard/Download/eduvaani_models'));
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        candidateDirs.add(Directory(p.join(ext.path, 'models', 'asr')));
        candidateDirs.add(Directory(p.join(ext.path, 'models')));
      }
    } catch (_) {}

    for (final dir in candidateDirs) {
      try {
        if (!await dir.exists()) continue;
        final files = await dir.list().toList();
        final fileNames = files.map((e) => p.basename(e.path).toLowerCase()).toList();

      // Find tokens.txt
      final tokensFile = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null && (p.basename(e.path).toLowerCase() == 'tokens.txt' ||
                p.basename(e.path).toLowerCase().endsWith('_tokens.txt') ||
                p.basename(e.path).toLowerCase().endsWith('-tokens.txt') ||
                p.basename(e.path).toLowerCase().contains('tokens')),
            orElse: () => null,
          );
      if (tokensFile == null) continue;

      // 1. Whisper check: encoder + decoder
      final encoder = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null &&
                p.extension(e.path).toLowerCase() == '.onnx' &&
                p.basename(e.path).toLowerCase().contains('encoder'),
            orElse: () => null,
          );
      final decoder = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null &&
                p.extension(e.path).toLowerCase() == '.onnx' &&
                p.basename(e.path).toLowerCase().contains('decoder') &&
                !p.basename(e.path).toLowerCase().contains('past'),
            orElse: () => null,
          );
      if (encoder != null && decoder != null) {
        return AsrModelPaths(
          type: AsrModelType.whisper,
          encoderPath: encoder.path,
          decoderPath: decoder.path,
          tokensPath: tokensFile.path,
        );
      }

      // 2. SenseVoice check
      final senseVoice = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null &&
                p.extension(e.path).toLowerCase() == '.onnx' &&
                (p.basename(e.path).toLowerCase().contains('sensevoice') ||
                 p.basename(e.path).toLowerCase().contains('sense_voice')),
            orElse: () => null,
          );
      if (senseVoice != null) {
        return AsrModelPaths(
          type: AsrModelType.senseVoice,
          modelPath: senseVoice.path,
          tokensPath: tokensFile.path,
        );
      }

      // 3. Generic CTC / Single ONNX model
      final singleModel = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null &&
                p.extension(e.path).toLowerCase() == '.onnx' &&
                !p.basename(e.path).toLowerCase().contains('indictrans') &&
                !p.basename(e.path).toLowerCase().contains('tts'),
            orElse: () => null,
          );
      if (singleModel != null) {
        return AsrModelPaths(
          type: AsrModelType.nemoCtc,
          modelPath: singleModel.path,
          tokensPath: tokensFile.path,
        );
      }
      } catch (_) {}
    }

    return null;
  }

  /// Locates installed Hindi TTS model files.
  ///
  /// Searches `<modelsDir>/tts/`, `<modelsDir>/tts-hindi/`, `<modelsDir>/hindi_tts/`,
  /// and `<modelsDir>/` for VITS/Piper ONNX model artifacts.
  Future<TtsModelPaths?> findTtsModel() async {
    final baseDir = await modelsDirectory();
    final List<Directory> candidateDirs = [
      Directory(p.join(baseDir.path, 'tts')),
      Directory(p.join(baseDir.path, 'tts-hindi')),
      Directory(p.join(baseDir.path, 'hindi_tts')),
      baseDir,
    ];

    try {
      candidateDirs.add(Directory('/sdcard/Download/eduvaani_models/tts'));
      candidateDirs.add(Directory('/sdcard/Download/eduvaani_models'));
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        candidateDirs.add(Directory(p.join(ext.path, 'models', 'tts')));
        candidateDirs.add(Directory(p.join(ext.path, 'models')));
      }
    } catch (_) {}

    for (final dir in candidateDirs) {
      try {
        if (!await dir.exists()) continue;
        final files = await dir.list().toList();

      // Find tokens.txt
      final tokensFile = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null && (p.basename(e.path).toLowerCase() == 'tokens.txt' ||
                p.basename(e.path).toLowerCase().endsWith('tts_tokens.txt')),
            orElse: () => null,
          );
      if (tokensFile == null) continue;

      // Find model.onnx (or vits/piper onnx)
      final ttsModel = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null &&
                p.extension(e.path).toLowerCase() == '.onnx' &&
                !p.basename(e.path).toLowerCase().contains('indictrans') &&
                !p.basename(e.path).toLowerCase().contains('asr') &&
                !p.basename(e.path).toLowerCase().contains('encoder') &&
                !p.basename(e.path).toLowerCase().contains('decoder'),
            orElse: () => null,
          );
      if (ttsModel == null) continue;

      // Optional lexicon or espeak data dir
      final lexiconFile = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e != null && (p.basename(e.path).toLowerCase() == 'lexicon.txt' ||
                p.basename(e.path).toLowerCase().endsWith('lexicon.txt')),
            orElse: () => null,
          );
      final espeakDir = files.cast<FileSystemEntity?>().firstWhere(
            (e) => e is Directory && p.basename(e.path).toLowerCase().contains('espeak'),
            orElse: () => null,
          );

      return TtsModelPaths(
        modelPath: ttsModel.path,
        tokensPath: tokensFile.path,
        lexiconPath: lexiconFile?.path,
        dataDirPath: espeakDir?.path,
      );
      } catch (_) {}
    }

    return null;
  }

  Future<bool> isAsrReady() async {
    final asr = await findAsrModel();
    return asr != null;
  }

  Future<bool> isTtsReady() async {
    final tts = await findTtsModel();
    return tts != null;
  }
}

enum AsrModelType { whisper, senseVoice, nemoCtc, none }

class AsrModelPaths {
  const AsrModelPaths({
    required this.type,
    this.modelPath,
    this.encoderPath,
    this.decoderPath,
    required this.tokensPath,
  });

  final AsrModelType type;
  final String? modelPath;
  final String? encoderPath;
  final String? decoderPath;
  final String tokensPath;
}

class TtsModelPaths {
  const TtsModelPaths({
    required this.modelPath,
    required this.tokensPath,
    this.dataDirPath,
    this.lexiconPath,
  });

  final String modelPath;
  final String tokensPath;
  final String? dataDirPath;
  final String? lexiconPath;
}

