import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_app/ml/model_manager.dart';
import 'package:flutter_app/ml/on_device_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File testWav;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    tempDir = await Directory.systemTemp.createTemp('eduvaani_test_');
    testWav = File(p.join(tempDir.path, 'sample.wav'));
    // Write a dummy 44-byte WAV header so it is a valid file
    final bytes = List<int>.filled(44 + 100, 0);
    await testWav.writeAsBytes(bytes);
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OnDeviceASRService', () {
    test('reports model not available when models directory is empty', () async {
      final asr = OnDeviceASRService();
      final available = await asr.isModelAvailable();
      expect(available, isFalse);
    });

    test('throws StateError when audio file does not exist', () async {
      final asr = OnDeviceASRService();
      expect(
        () => asr.transcribeHindi(p.join(tempDir.path, 'missing.wav')),
        throwsA(isA<StateError>()),
      );
    });

    test('falls back to demo transcript when real model is missing', () async {
      final asr = OnDeviceASRService();
      final result = await asr.transcribeHindi(
        testWav.path,
        demoTranscript: 'शांत बैठो।',
      );
      expect(result.transcript, 'शांत बैठो।');
      expect(result.isMock, isTrue);
      expect(result.duration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('throws ModelUnavailableException when model missing and no demoTranscript', () async {
      final asr = OnDeviceASRService();
      expect(
        () => asr.transcribeHindi(testWav.path),
        throwsA(isA<ModelUnavailableException>()),
      );
    });
  });

  group('OnDeviceTTSService', () {
    test('reports model not available when models directory is empty', () async {
      final tts = OnDeviceTTSService();
      final available = await tts.isModelAvailable();
      expect(available, isFalse);
    });

    test('throws ArgumentError on empty input', () async {
      final tts = OnDeviceTTSService();
      expect(
        () => tts.synthesizeSantali('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('synthesizes Santali with phoneme fallback when model is not installed', () async {
      final tts = OnDeviceTTSService();
      // Ol Chiki text: ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ (Sit quietly)
      final result = await tts.synthesizeSantali(
        'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ ᱾',
        speakerId: 1,
        speed: 1.0,
      );

      expect(result.audioPath, isNotEmpty);
      expect(File(result.audioPath).existsSync(), isTrue);
      expect(result.isMock, isTrue);
    });
  });
}
