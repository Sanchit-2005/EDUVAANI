import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_app/ml/model_manager.dart';
import 'package:flutter_app/ml/on_device_services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Physical Device Offline Voice Pipeline Verification', () {
    late ModelManager modelManager;
    late OnDeviceASRService asrService;
    late OnDeviceTranslationService translationService;
    late OnDeviceTTSService ttsService;
    late Directory appSupportDir;

    setUpAll(() async {
      modelManager = ModelManager();
      asrService = OnDeviceASRService(manager: modelManager);
      translationService = OnDeviceTranslationService(manager: modelManager);
      ttsService = OnDeviceTTSService(manager: modelManager);
      appSupportDir = await getApplicationSupportDirectory();

      try {
        final downloadModels = Directory('/sdcard/Download/eduvaani_models');
        final intModels = Directory(p.join(appSupportDir.path, 'models'));
        if (await downloadModels.exists()) {
          print('[setUpAll] Syncing models from /sdcard/Download/eduvaani_models to internal storage...');
          await intModels.create(recursive: true);
          for (final dirName in ['asr', 'tts']) {
            final srcDir = Directory(p.join(downloadModels.path, dirName));
            final dstDir = Directory(p.join(intModels.path, dirName));
            if (await srcDir.exists()) {
              await dstDir.create(recursive: true);
              for (final entity in await srcDir.list(recursive: true).toList()) {
                final rel = p.relative(entity.path, from: srcDir.path);
                final target = p.join(dstDir.path, rel);
                if (entity is Directory) {
                  await Directory(target).create(recursive: true);
                } else if (entity is File) {
                  final targetFile = File(target);
                  if (!await targetFile.exists() || await targetFile.length() != await entity.length()) {
                    await Directory(p.dirname(target)).create(recursive: true);
                    await entity.copy(target);
                  }
                }
              }
            }
          }
          final downloadAudio = File(p.join(downloadModels.path, 'audio', 'namaste.wav'));
          final intAudio = File(p.join(appSupportDir.path, 'namaste.wav'));
          if (await downloadAudio.exists()) {
            await downloadAudio.copy(intAudio.path);
          }
        }
      } catch (e) {
        print('[setUpAll] Note on sync: $e');
      }
    });

    tearDownAll(() {
      asrService.dispose();
      ttsService.dispose();
    });

    testWidgets('1. Model files physical presence and readiness checks',
        (WidgetTester tester) async {
      print('\n======================================================');
      print('VERIFICATION ITEM 1: PHYSICAL MODEL DETECTION ON DEVICE');
      print('======================================================');
      print('App Support Directory: ${appSupportDir.path}');

      final asrReady = await modelManager.isAsrReady();
      final asrModelPaths = await modelManager.findAsrModel();
      print('isAsrReady(): $asrReady');
      print('ASR Model Type: ${asrModelPaths?.type}');
      print('ASR Encoder: ${asrModelPaths?.encoderPath}');
      print('ASR Decoder: ${asrModelPaths?.decoderPath}');
      print('ASR Tokens: ${asrModelPaths?.tokensPath}');

      expect(asrReady, isTrue, reason: 'ASR model files must be physically present on device');
      expect(asrModelPaths, isNotNull);
      expect(File(asrModelPaths!.encoderPath!).existsSync(), isTrue);
      expect(File(asrModelPaths.decoderPath!).existsSync(), isTrue);
      expect(File(asrModelPaths.tokensPath).existsSync(), isTrue);

      final ttsReady = await modelManager.isTtsReady();
      final ttsModelPaths = await modelManager.findTtsModel();
      print('isTtsReady(): $ttsReady');
      print('TTS Model: ${ttsModelPaths?.modelPath}');
      print('TTS Tokens: ${ttsModelPaths?.tokensPath}');
      print('TTS DataDir: ${ttsModelPaths?.dataDirPath}');

      expect(ttsReady, isTrue, reason: 'TTS model files must be physically present on device');
      expect(ttsModelPaths, isNotNull);
      expect(File(ttsModelPaths!.modelPath).existsSync(), isTrue);
      expect(File(ttsModelPaths.tokensPath).existsSync(), isTrue);
      expect(Directory(ttsModelPaths.dataDirPath!).existsSync(), isTrue);
    });

    testWidgets('2. Full offline pipeline inference on physical device with real spoken Hindi',
        (WidgetTester tester) async {
      print('\n======================================================');
      print('VERIFICATION ITEM 2: REAL INFERENCE PIPELINE (isMock: false)');
      print('======================================================');

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Verifying'))));

      // Test with real spoken Hindi WAV
      final candidateAudios = [
        '/sdcard/Download/eduvaani_models/audio/namaste.wav',
        p.join(appSupportDir.path, 'namaste.wav'),
      ];
      final audioPath = candidateAudios.firstWhere(
        (p) => File(p).existsSync(),
        orElse: () => candidateAudios.first,
      );
      print('Input Audio Path: $audioPath');
      expect(File(audioPath).existsSync(), isTrue, reason: 'Test audio must be present');
      final audioBytes = File(audioPath).lengthSync();
      print('Input Audio Size: $audioBytes bytes');

      // Stage 1: Offline ASR
      print('\n--- STAGE 1: Offline ASR (Whisper tiny INT8) ---');
      final asrResult = await asrService.transcribeHindi(audioPath);
      print('Transcript: "${asrResult.transcript}"');
      print('ASR Duration: ${asrResult.duration.inMilliseconds}ms');
      print('ASR isMock: ${asrResult.isMock}');

      expect(asrResult.isMock, isFalse, reason: 'ASR MUST NOT be mock on real run!');
      expect(asrResult.transcript.trim(), isNotEmpty);

      // Stage 2: Offline MT (IndicTrans2 INT8)
      print('\n--- STAGE 2: Offline MT (IndicTrans2 INT8) ---');
      // Use Hindi text corresponding to greeting
      final hindiText = asrResult.transcript.isNotEmpty ? asrResult.transcript : 'नमस्ते';
      final mtResult = await translationService.translate(
        text: hindiText,
        sourceLanguage: 'hin_Deva',
        targetLanguage: 'sat_Olck',
      );
      print('MT Input: "$hindiText"');
      print('MT Output (Santali Ol Chiki): "${mtResult.output}"');
      print('MT Model: "${mtResult.model}"');
      print('MT isPrototype: ${mtResult.isPrototype}');

      expect(mtResult.isPrototype, isFalse, reason: 'MT must be real IndicTrans2 on-device');
      expect(mtResult.output.trim(), isNotEmpty);

      // Stage 3: Offline TTS (Option A: Ol Chiki -> Devanagari phonemes -> Piper VITS)
      print('\n--- STAGE 3: Offline TTS (Option A phonetics -> Piper VITS) ---');
      final ttsResult = await ttsService.synthesizeSantali(
        mtResult.output,
        speakerId: 0,
        speed: 1.0,
        fallbackToDemo: false,
      );
      print('TTS Output WAV: "${ttsResult.audioPath}"');
      print('TTS Duration: ${ttsResult.duration.inMilliseconds}ms');
      print('TTS isMock: ${ttsResult.isMock}');

      expect(ttsResult.isMock, isFalse, reason: 'TTS MUST NOT be mock on real run!');
      expect(ttsResult.audioPath, isNotNull);
      final ttsFile = File(ttsResult.audioPath!);
      expect(ttsFile.existsSync(), isTrue);
      expect(ttsFile.lengthSync(), greaterThan(1000), reason: 'Generated audio must contain real samples');
      print('Generated Audio File Size: ${ttsFile.lengthSync()} bytes');
      print('======================================================');
      print('OFFLINE VOICE TRANSLATION PIPELINE FULLY VERIFIED ON DEVICE');
      print('======================================================\n');
    });
  });
}
