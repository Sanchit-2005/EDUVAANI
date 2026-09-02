import 'dart:io';

import 'package:flutter_app/services/speech_recognition_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock ASR returns the selected Hindi demo transcription', () async {
    final audio = File('${Directory.systemTemp.path}/eduvaani_mock_asr_test.m4a');
    await audio.writeAsBytes([0]);
    addTearDown(() => audio.delete());

    final service = MockSpeechRecognitionService(demoTranscript: 'शांत बैठो।');
    final result = await service.transcribeHindi(audio.path);

    expect(result.transcript, 'शांत बैठो।');
    expect(result.isMock, isTrue);
    expect(result.duration, isNot(Duration.zero));
  });
}
