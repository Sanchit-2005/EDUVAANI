import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/text_translator_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const longModelName =
      'ai4bharat/indictrans2-indic-indic-dist-320M (On-Device)';

  const onDeviceChannel = MethodChannel('eduvaani/on_device_translation');

  group('TextTranslatorScreen / ResultCard UI & Overflow Tests', () {
    testWidgets(
      'Hindi -> Santali: renders on narrow 320px screen with long model name without ANY overflow, copies with checkmark',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Mock on-device translation channel
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          onDeviceChannel,
          (MethodCall methodCall) async {
            if (methodCall.method == 'translate') {
              return {
                'success': true,
                'translation': 'ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾',
              };
            }
            return null;
          },
        );

        // Intercept clipboard calls to verify copy behavior
        String? clipboardData;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final args = methodCall.arguments as Map<dynamic, dynamic>;
              clipboardData = args['text'] as String?;
              return null;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TextTranslatorScreen(),
            ),
          ),
        );
        await tester.pump();

        // 1. Enter text in input field
        final inputField = find.byType(TextField);
        expect(inputField, findsOneWidget);
        await tester.enterText(inputField, 'शांत बैठो');
        await tester.pump();

        // 2. Tap Translate button
        final translateButton = find.widgetWithText(FilledButton, 'Translate');
        expect(translateButton, findsOneWidget);
        await tester.tap(translateButton);
        await tester.pump(); // Start translation
        await tester.pump(const Duration(milliseconds: 100)); // Finish async translate
        await tester.pump();

        // Verify that NO overflow exception occurred
        expect(tester.takeException(), isNull);

        // 3. Verify translated output and model badge exist
        expect(find.text('ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾'), findsOneWidget);
        expect(find.text(longModelName), findsOneWidget);

        // 4. Verify copy button exists and tap it
        final copyButtonFinder = find.byKey(const ValueKey('copy-translation-button'));
        expect(copyButtonFinder, findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

        await tester.tap(copyButtonFinder);
        await tester.pump();

        // Check clipboard got translated text
        expect(clipboardData, equals('ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾'));

        // Checkmark icon is shown
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.text('Copied to clipboard'), findsOneWidget);

        // Fast forward 2 seconds + animation time: icon reverts to copy_rounded
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);

        // Verify again that no overflow warning occurred throughout the interaction
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Santali -> Hindi direction also copies and has no overflow on narrow screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          onDeviceChannel,
          (MethodCall methodCall) async {
            if (methodCall.method == 'translate') {
              return {
                'success': true,
                'translation': 'शांत बैठो।',
              };
            }
            return null;
          },
        );

        String? clipboardData;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final args = methodCall.arguments as Map<dynamic, dynamic>;
              clipboardData = args['text'] as String?;
              return null;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TextTranslatorScreen(),
            ),
          ),
        );
        await tester.pump();

        // Switch to Santali -> Hindi tab
        final santaliTab = find.text('Santali → Hindi');
        expect(santaliTab, findsOneWidget);
        await tester.tap(santaliTab);
        await tester.pump();

        // Enter Santali input
        final inputField = find.byType(TextField);
        await tester.enterText(inputField, 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾');
        await tester.pump();

        // Tap Translate
        final translateButton = find.widgetWithText(FilledButton, 'Translate');
        await tester.tap(translateButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('शांत बैठो।'), findsOneWidget);

        // Copy button exists
        final copyButtonFinder = find.byKey(const ValueKey('copy-translation-button'));
        expect(copyButtonFinder, findsOneWidget);

        // Tap Copy
        await tester.tap(copyButtonFinder);
        await tester.pump();

        expect(clipboardData, equals('शांत बैठो।'));
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.text('Copied to clipboard'), findsOneWidget);

        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Copy button is disabled when output is empty',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          onDeviceChannel,
          (MethodCall methodCall) async {
            if (methodCall.method == 'translate') {
              return {
                'success': true,
                'translation': ' ',
              };
            }
            return null;
          },
        );

        // Also test _ResultCard directly for empty output disabled state
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TextTranslatorScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('copy-translation-button')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
