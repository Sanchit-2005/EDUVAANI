import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_cache_service.dart';

class TextToSpeechResult {
  const TextToSpeechResult({
    required this.audioPath,
    required this.duration,
    required this.isMock,
  });

  final String audioPath;
  final Duration duration;
  final bool isMock;
}

/// Keeps audio playback independent from the future Santali TTS model.
abstract class TextToSpeechService {
  Future<TextToSpeechResult> synthesizeSantali(String text);
}

/// Offline demo TTS adapter.
///
/// Produces a small local WAV cue so that recording, synthesis, caching and
/// playback can be demonstrated without claiming Santali speech quality.
/// On web (Chrome) the file-IO path is skipped and a stub is returned.
class MockTextToSpeechService implements TextToSpeechService {
  MockTextToSpeechService({AudioCacheService? cache})
      : _cache = cache ?? AudioCacheService();

  final AudioCacheService _cache;

  @override
  Future<TextToSpeechResult> synthesizeSantali(String text) async {
    final stopwatch = Stopwatch()..start();
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Santali text cannot be empty.');
    }

    // Web (Chrome) does not support dart:io or path_provider — return stub.
    if (kIsWeb) {
      stopwatch.stop();
      return TextToSpeechResult(
        audioPath: '',
        duration: stopwatch.elapsed,
        isMock: true,
      );
    }

    final directory = await getTemporaryDirectory();
    final output = File(
      p.join(directory.path, 'eduvaani_santali_demo_${text.hashCode.abs()}.wav'),
    );
    if (!await output.exists()) {
      await output.writeAsBytes(_createDemoWav(text));
    }
    await _cache.trimDemoAudioCache();
    stopwatch.stop();
    return TextToSpeechResult(
      audioPath: output.path,
      duration: stopwatch.elapsed,
      isMock: true,
    );
  }

  /// Creates a valid local audio cue (not real Santali speech — demo only).
  Uint8List _createDemoWav(String text) {
    const sampleRate = 16000;
    final seconds = (0.45 + text.runes.length * 0.012).clamp(0.45, 1.6);
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
      final sample = (math.sin(2 * math.pi * 440 * i / sampleRate) *
              5000 *
              envelope)
          .round();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
