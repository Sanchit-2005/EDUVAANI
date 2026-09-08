import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_app/services/worksheet_pdf_fonts.dart';
import 'package:flutter_app/services/worksheet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('worksheet generator creates a local PDF', () async {
    final bytes = await WorksheetService().buildBilingualWorksheet(
      const WorksheetData(
        grade: 'Grade 1',
        subject: 'Foundational Numeracy',
        topic: 'Counting 1-10',
        hindiInstruction: 'अब मिलकर गिनो।',
        santaliInstruction: 'ᱱᱤᱛᱚᱜ ᱢᱤᱫ ᱥᱟᱶᱛᱮ ᱞᱮᱠᱷᱟ ᱯᱮ᱾',
      ),
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('worksheet PDF embeds the Ol Chiki and Devanagari fonts', () async {
    // Without embedded TTF programs a PDF viewer substitutes fonts and Ol
    // Chiki/Devanagari render as empty boxes — this is the regression guard
    // for the Santali tofu bug.
    final bytes = await WorksheetService().buildBilingualWorksheet(
      const WorksheetData(
        grade: 'Grade 1',
        subject: 'Foundational Numeracy',
        topic: 'Counting 1-10',
        hindiInstruction: 'अब मिलकर गिनो।',
        santaliInstruction: 'ᱱᱤᱛᱚᱜ ᱢᱤᱫ ᱥᱟᱶᱛᱮ ᱞᱮᱠᱷᱟ ᱯᱮ᱾',
      ),
    );

    final raw = String.fromCharCodes(bytes);
    final embeddedFontCount = '/FontFile2'.allMatches(raw).length;
    expect(
      embeddedFontCount,
      greaterThanOrEqualTo(2),
      reason:
          'Expected at least the Ol Chiki and Devanagari TTF programs to be '
          'embedded (found $embeddedFontCount /FontFile2 entries). Without '
          'them Santali/Hindi text renders as tofu boxes.',
    );
  });

  test('font loader loads and caches all four script fonts', () async {
    final fonts = await WorksheetPdfFonts.load();
    expect(fonts.olChiki, isNotNull);
    expect(fonts.olChikiBold, isNotNull);
    expect(fonts.devanagari, isNotNull);
    expect(fonts.devanagariBold, isNotNull);
    expect(fonts.fontFallback, containsAll([fonts.olChiki, fonts.devanagari]));

    // A second load must reuse the cached instance.
    final again = await WorksheetPdfFonts.load();
    expect(identical(again, fonts), isTrue);
  });

  test('Ol Chiki coverage guard accepts the bundled Santali font', () async {
    final data =
        await rootBundle.load('assets/fonts/NotoSansOlChiki-Regular.ttf');
    WorksheetPdfFonts.assertCoversOlChiki(
      TtfParser(data),
      'assets/fonts/NotoSansOlChiki-Regular.ttf',
    );
  });

  test('Ol Chiki coverage guard rejects a font without Ol Chiki glyphs',
      () async {
    // The Devanagari font has zero Ol Chiki codepoints: it must be rejected
    // with a clear error instead of silently producing empty boxes.
    final data =
        await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
    expect(
      () => WorksheetPdfFonts.assertCoversOlChiki(
        TtfParser(data),
        'assets/fonts/NotoSansDevanagari-Regular.ttf',
      ),
      throwsA(
        isA<WorksheetFontException>().having(
          (error) => error.message,
          'message',
          contains('empty boxes'),
        ),
      ),
    );
  });

  test('script-aware spans assign fonts per script', () async {
    final fonts = await WorksheetPdfFonts.load();
    const mixed = 'Count: 5 ᱜᱮᱽ और गिनो';
    final span = fonts.scriptAwareSpan(mixed, style: null);

    // Mixed text must split into multiple child runs.
    expect(span.children, isNotNull);
    expect(span.children!.length, greaterThan(1));

    // Joining the runs must reconstruct the original text exactly.
    final texts = span.children!
        .whereType<pw.TextSpan>()
        .map((child) => child.text)
        .join();
    expect(texts, mixed);

    // The Santali and Hindi runs must each carry their script font.
    final runFonts = span.children!
        .whereType<pw.TextSpan>()
        .map((child) => child.style?.fontNormal)
        .toSet();
    expect(runFonts, containsAll([fonts.olChiki, fonts.devanagari]));
    expect(runFonts.contains(fonts.olChiki), isTrue);
    expect(runFonts.contains(fonts.devanagari), isTrue);
  });
}
