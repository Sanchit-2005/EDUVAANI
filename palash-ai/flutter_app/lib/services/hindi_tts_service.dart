import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_cache_service.dart';

class HindiTextToSpeechResult {
  const HindiTextToSpeechResult({
    required this.audioPath,
    required this.duration,
    required this.isMock,
  });

  final String audioPath;
  final Duration duration;
  final bool isMock;
}

/// Contract for Hindi Text-to-Speech synthesis.
///
/// Keeps Hindi TTS generation independent from the future production model.
/// Supports offline playback of Hindi translations.
abstract class HindiTtsService {
  Future<HindiTextToSpeechResult> synthesizeHindi(String text);
}

/// Offline demo Hindi TTS adapter.
///
/// Produces a small local WAV cue for demonstration without claiming
/// Hindi speech quality. Replaced by a real model in production.
class MockHindiTtsService implements HindiTtsService {
  MockHindiTtsService({AudioCacheService? cache})
    : _cache = cache ?? AudioCacheService();

  final AudioCacheService _cache;

  @override
  Future<HindiTextToSpeechResult> synthesizeHindi(String text) async {
    final stopwatch = Stopwatch()..start();
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Hindi text cannot be empty.');
    }

    final directory = await getTemporaryDirectory();
    final output = File(
      p.join(directory.path, 'eduvaani_hindi_demo_${text.hashCode.abs()}.wav'),
    );

    if (!await output.exists()) {
      await output.writeAsBytes(_createDemoWav(text));
    }

    await _cache.trimDemoAudioCache();
    stopwatch.stop();

    return HindiTextToSpeechResult(
      audioPath: output.path,
      duration: stopwatch.elapsed,
      isMock: true,
    );
  }

  /// Creates a valid local audio cue.
  /// It is deliberately not represented as spoken Hindi;
  /// a real model will replace this adapter in a later phase.
  Uint8List _createDemoWav(String text) {
    const sampleRate = 16000;
    final seconds = (0.45 + text.runes.length * 0.012).clamp(0.45, 1.8);
    final sampleCount = (sampleRate * seconds).round();
    final dataBytes = sampleCount * 2;
    final bytes = ByteData(44 + dataBytes);

    bytes.setUint32(0, 0x52494646, Endian.big); // RIFF
    bytes.setUint32(4, 36 + dataBytes, Endian.little);
    bytes.setUint32(8, 0x57415645, Endian.big); // WAVE
    bytes.setUint32(12, 0x666d7420, Endian.big); // fmt
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    bytes.setUint32(36, 0x64617461, Endian.big); // data
    bytes.setUint32(40, dataBytes, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      final envelope = i < 100 || i > sampleCount - 100 ? 0.25 : 1.0;
      // Use different frequency for Hindi (440 Hz is standard, but vary it)
     final frequency = 400.0 + (math.sin(i / 100) * 50);
      final sample =
          (math.sin(2 * math.pi * frequency * i / sampleRate) * 5000 * envelope)
              .round();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}

/// ONNX-based Hindi TTS implementation (placeholder).
///
/// This would use ONNX Runtime Mobile with an offline Hindi TTS model.
/// To be implemented when the model is available.
class OnnxHindiTtsService implements HindiTtsService {
  OnnxHindiTtsService({this.modelPath});

  final String? modelPath;

  @override
  Future<HindiTextToSpeechResult> synthesizeHindi(String text) async {
    throw UnimplementedError(
      'ONNX Hindi TTS not yet implemented. '
      'Requires a trained Hindi speech synthesis model.',
    );
  }
}
