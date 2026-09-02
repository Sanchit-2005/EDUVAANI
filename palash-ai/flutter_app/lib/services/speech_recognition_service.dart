import 'dart:async';
import 'dart:io';

/// Result from a Hindi speech-recognition attempt.
class SpeechRecognitionResult {
  const SpeechRecognitionResult({
    required this.transcript,
    required this.duration,
    required this.isMock,
  });

  final String transcript;
  final Duration duration;
  final bool isMock;
}

/// Keeps the user interface independent from the ASR engine.
abstract class SpeechRecognitionService {
  Future<SpeechRecognitionResult> transcribeHindi(String audioPath);
}

/// Offline demo ASR adapter.
///
/// It validates that a recording was made, then returns a teacher-selected
/// classroom phrase. Replace this adapter with an on-device ASR engine later
/// without changing the voice screen.
class MockSpeechRecognitionService implements SpeechRecognitionService {
  MockSpeechRecognitionService({required String demoTranscript})
      : _demoTranscript = demoTranscript;

  final String _demoTranscript;

  @override
  Future<SpeechRecognitionResult> transcribeHindi(String audioPath) async {
    final stopwatch = Stopwatch()..start();
    final recording = File(audioPath);
    if (!await recording.exists()) {
      throw StateError('The recording could not be found. Please record again.');
    }

    // This small delay represents the actual work of the offline demo adapter.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    stopwatch.stop();
    return SpeechRecognitionResult(
      transcript: _demoTranscript,
      duration: stopwatch.elapsed,
      isMock: true,
    );
  }
}
