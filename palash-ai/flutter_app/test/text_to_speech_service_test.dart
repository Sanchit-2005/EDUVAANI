import 'dart:io';

import 'package:flutter_app/services/text_to_speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock TTS creates a playable local WAV file', () async {
    final result = await MockTextToSpeechService().synthesizeSantali('ᱥᱟᱱᱛᱤ');
    final audio = File(result.audioPath);

    expect(await audio.exists(), isTrue);
    expect(await audio.length(), greaterThan(44));
    expect(result.isMock, isTrue);
    expect(result.duration, isNot(Duration.zero));
  });
}
