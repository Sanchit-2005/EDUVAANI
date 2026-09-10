import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/screens/voice_translator_screen.dart';
import 'package:flutter_app/widgets/app_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const onDeviceChannel = MethodChannel('eduvaani/on_device_translation');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      onDeviceChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'translate') {
          return {
            'success': true,
            'translation': 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ ᱾',
          };
        }
        return null;
      },
    );
  });

  Widget createSubject() {
    return const MaterialApp(
      home: Scaffold(
        body: VoiceTranslatorScreen(),
      ),
    );
  }

  group('VoiceTranslatorScreen UI & Offline Pipeline Tests', () {
    testWidgets('renders initial UI with app bar, mic button, and disclaimer',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Offline Voice Translator'), findsOneWidget);
      expect(
        find.text('Tap mic to speak (hold a beat before speaking)'),
        findsOneWidget,
      );
      expect(find.text('Voice Speaker:'), findsOneWidget);
      expect(find.text('Female (Priyamvada)'), findsOneWidget);
      expect(find.textContaining('Male'), findsOneWidget);
      expect(find.text('Or pick classroom phrase'), findsOneWidget);
    });

    testWidgets('tapping a classroom phrase runs pipeline and displays results',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on phrase "शांत बैठो।"
      final phraseFinder = find.text('शांत बैठो।');
      expect(phraseFinder, findsOneWidget);
      await tester.tap(phraseFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));

      // Check Recognized Speech card appears with editable text
      expect(find.text('Recognised Speech (Hindi)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Re-translate'), findsOneWidget);

      // Check Santali Translation card appears
      expect(find.text('Santali Translation'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'indictrans2', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );

      // Check Option A Disclaimer is visible
      expect(
        find.textContaining('Approximate pronunciation (Option A)'),
        findsOneWidget,
      );

      // Check Replay Santali button appears or is synthesizing
      expect(
        find.byWidgetPredicate(
          (w) => w is PrimaryButton,
        ),
        findsOneWidget,
      );
    });

    testWidgets('speaker gender toggle switches between male and female',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pump(const Duration(milliseconds: 200));

      final femaleChip = find.text('Female (Priyamvada)');
      await tester.tap(femaleChip);
      await tester.pump(const Duration(milliseconds: 200));

      final maleChip = find.byWidgetPredicate(
        (w) => w is ChoiceChip && w.avatar is Icon && (w.avatar as Icon).icon == Icons.male_rounded,
      );
      await tester.tap(maleChip);
      await tester.pump(const Duration(milliseconds: 200));

      expect(maleChip, findsOneWidget);
      expect(femaleChip, findsOneWidget);
    });

    testWidgets('editing Hindi text and tapping Re-translate updates results',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pump(const Duration(milliseconds: 200));

      // Select phrase first
      await tester.tap(find.text('शांत बैठो।'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Edit the text in the TextField
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'बहुत अच्छा।');
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Re-translate
      await tester.tap(find.text('Re-translate'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('Santali Translation'), findsOneWidget);
    });

    testWidgets('copy button copies Santali Ol Chiki text to clipboard',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(createSubject());
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('शांत बैठो।'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final copyButton = find.byIcon(Icons.copy_rounded);
      expect(copyButton, findsOneWidget);
      await tester.tap(copyButton);
      await tester.pump(const Duration(milliseconds: 200));

      expect(copiedText, isNotEmpty);
      expect(
        find.text('Santali translation copied to clipboard.'),
        findsOneWidget,
      );
    });
  });
}
