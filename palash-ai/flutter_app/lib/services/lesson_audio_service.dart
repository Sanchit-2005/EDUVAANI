import 'package:just_audio/just_audio.dart';

import '../ml/on_device_services.dart';
import 'hindi_tts_service.dart';
import 'text_to_speech_service.dart';

/// Coordinates instruction playback for lesson screens.
class LessonAudioService {
  LessonAudioService({
    AudioPlayer? player,
    HindiTtsService? hindiTts,
    TextToSpeechService? santaliTts,
  })  : _player = player ?? AudioPlayer(),
        _hindiTts = hindiTts ?? MockHindiTtsService(),
        _santaliTts = santaliTts ?? OnDeviceTTSService();

  final AudioPlayer _player;
  final HindiTtsService _hindiTts;
  final TextToSpeechService _santaliTts;

  bool get isPlaying => _player.playing;

  Future<void> playHindiInstruction(String text) async {
    final result = await _hindiTts.synthesizeHindi(text);
    await _playFile(result.audioPath);
  }

  Future<void> playSantaliInstruction(String text) async {
    final result = await _santaliTts.synthesizeSantali(text);
    await _playFile(result.audioPath);
  }

  Future<void> _playFile(String path) async {
    if (path.isEmpty) {
      throw UnsupportedError('Local lesson audio is not available on web.');
    }
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
