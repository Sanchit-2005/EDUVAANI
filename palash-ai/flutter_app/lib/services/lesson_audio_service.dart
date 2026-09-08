import 'package:just_audio/just_audio.dart';

import 'hindi_tts_service.dart';
import 'text_to_speech_service.dart';

/// Coordinates instruction playback for lesson screens.
///
/// The service deliberately uses the existing offline TTS adapters. Their
/// current output is a demo audio cue rather than verified spoken Hindi or
/// Santali, so callers must keep the UI's preview disclaimer visible until
/// recorded audio or production TTS models are supplied.
class LessonAudioService {
  LessonAudioService({
    AudioPlayer? player,
    HindiTtsService? hindiTts,
    TextToSpeechService? santaliTts,
  })  : _player = player ?? AudioPlayer(),
        _hindiTts = hindiTts ?? MockHindiTtsService(),
        _santaliTts = santaliTts ?? MockTextToSpeechService();

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
