import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'worksheet_pdf_fonts.dart';

// ── Data models ──────────────────────────────────────────────────────────────

class WorksheetData {
  const WorksheetData({
    required this.grade,
    required this.subject,
    required this.topic,
    required this.hindiInstruction,
    required this.santaliInstruction,
  });

  final String grade;
  final String subject;
  final String topic;
  final String hindiInstruction;
  final String santaliInstruction;
}

/// A single question authored by a teacher for a custom assignment.
class CustomQuestion {
  const CustomQuestion({
    required this.hindiText,
    this.santaliText,
    this.englishText,
    this.isAiTranslated = false,
    this.questionType = 'text',
  });

  final String hindiText;
  final String? santaliText;
  final String? englishText;

  /// true when the Santali text was produced by the AI translation pipeline
  /// rather than hand-entered by the teacher.
  final bool isAiTranslated;

  /// Hint for the renderer: 'text' = plain written answer, 'count' = counting
  /// activity, 'circle' = circle the correct answer, 'match' = draw lines.
  final String questionType;

  Map<String, Object?> toMap() => {
        'hindiText': hindiText,
        'santaliText': santaliText,
        'englishText': englishText,
        'isAiTranslated': isAiTranslated,
        'questionType': questionType,
      };

  factory CustomQuestion.fromMap(Map<String, dynamic> map) => CustomQuestion(
        hindiText: map['hindiText'] as String? ?? '',
        santaliText: map['santaliText'] as String?,
        englishText: map['englishText'] as String?,
        isAiTranslated: (map['isAiTranslated'] as bool?) ?? false,
        questionType: map['questionType'] as String? ?? 'text',
      );
}

/// Parameters for a teacher-authored custom assignment worksheet.
class CustomWorksheetData {
  const CustomWorksheetData({
    required this.grade,
    required this.subject,
    required this.topic,
    required this.questions,
    this.includeHindi = true,
    this.includeSantali = true,
    this.includeEnglish = false,
  });

  final String grade;
  final String subject;
  final String topic;
  final List<CustomQuestion> questions;
  final bool includeHindi;
  final bool includeSantali;
  final bool includeEnglish;
}

// ── Palette ──────────────────────────────────────────────────────────────────

class _WsPalette {
  _WsPalette({required this.highContrast});

  final bool highContrast;

  // Hindi language box
  PdfColor get hindiBoxBg =>
      highContrast ? PdfColors.white : const PdfColor.fromInt(0xFFFFF3E0);
  PdfColor get hindiBoxBorder =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFFFF6F00);
  PdfColor get hindiLabelFg =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFFE65100);

  // Santali language box
  PdfColor get santaliBoxBg =>
      highContrast ? PdfColors.white : const PdfColor.fromInt(0xFFE8F5E9);
  PdfColor get santaliBoxBorder =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFF2E7D32);
  PdfColor get santaliLabelFg =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFF1B5E20);

  // English language box
  PdfColor get englishBoxBg =>
      highContrast ? PdfColors.white : const PdfColor.fromInt(0xFFE3F2FD);
  PdfColor get englishBoxBorder =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFF1565C0);
  PdfColor get englishLabelFg =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFF0D47A1);

  // Header
  PdfColor get headerBg =>
      highContrast ? PdfColors.white : const PdfColor.fromInt(0xFF0D9488);
  PdfColor get headerFg =>
      highContrast ? PdfColors.black : PdfColors.white;
  PdfColor get headerSubFg =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFFB2DFDB);

  // General
  PdfColor get sectionDivider =>
      highContrast ? PdfColors.grey700 : const PdfColor.fromInt(0xFF0D9488);
  PdfColor get infoRowBorder =>
      highContrast ? PdfColors.black : PdfColors.blueGrey300;
  PdfColor get questionAccent =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFF0D9488);
  PdfColor get footerFg =>
      highContrast ? PdfColors.black : PdfColors.grey600;
  PdfColor get activityIconFg =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFFFF8F00);
  PdfColor get numberOptionBg =>
      highContrast ? PdfColors.white : const PdfColor.fromInt(0xFFF5F5F5);
  PdfColor get numberOptionBorder =>
      highContrast ? PdfColors.black : const PdfColor.fromInt(0xFF0D9488);
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Builds worksheets entirely on the device. No API call is made.
///
/// Both [buildBilingualWorksheet] (standard template) and
/// [buildCustomWorksheet] (teacher-authored) share the same PDF engine,
/// font pipeline and page layout.
class WorksheetService {
  // ── Standard bilingual worksheet ─────────────────────────────────────────

  Future<Uint8List> buildBilingualWorksheet(
    WorksheetData data, {
    bool highContrast = false,
  }) async {
    final fonts = await WorksheetPdfFonts.load();
    final pal = _WsPalette(highContrast: highContrast);
    final isGrade1 = _isEarlyGrade(data.grade);
    final bodySize = isGrade1 ? 14.0 : 12.0;
    final questionSize = isGrade1 ? 15.0 : 13.0;

    final document = _makeDocument(fonts);
    document.addPage(
      _makePage(build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _brandedHeader(pal, data.grade, data.subject, data.topic),
            pw.SizedBox(height: 12),
            _studentInfoRow(pal),
            pw.SizedBox(height: 16),
            _thinDivider(pal),
            pw.SizedBox(height: 16),

            // ── Instruction language boxes ──────────────────
            _languageBox(
              heading: 'Hindi  (हिन्दी)',
              text: data.hindiInstruction,
              fonts: fonts,
              pal: pal,
              bodySize: bodySize,
              bg: pal.hindiBoxBg,
              border: pal.hindiBoxBorder,
              labelFg: pal.hindiLabelFg,
            ),
            pw.SizedBox(height: 10),
            _languageBox(
              heading: 'Santali  (ᱥᱟᱱᱛᱟᱲᱤ)',
              text: data.santaliInstruction,
              fonts: fonts,
              pal: pal,
              bodySize: bodySize,
              bg: pal.santaliBoxBg,
              border: pal.santaliBoxBorder,
              labelFg: pal.santaliLabelFg,
            ),
            pw.SizedBox(height: 22),
            _thinDivider(pal),
            pw.SizedBox(height: 18),

            // ── Activity 1: Counting ────────────────────────
            _questionLabel(fonts, pal, questionSize,
                '1. Count the objects. / वस्तुओं को गिनो।'),
            pw.SizedBox(height: 12),
            _iconShapeRow(pal, count: 5, shape: 'star'),
            pw.SizedBox(height: 12),
            _answerLine(pal, 'How many?'),
            pw.SizedBox(height: 24),

            // ── Activity 2: Circle the number ───────────────
            _questionLabel(fonts, pal, questionSize,
                '2. Circle the correct number. / सही संख्या पर गोला लगाओ।'),
            pw.SizedBox(height: 12),
            _numberOptionRow(pal),
            pw.Spacer(),

            _footer(pal),
          ],
        );
      }),
    );
    return document.save();
  }

  // ── Custom assignment worksheet ──────────────────────────────────────────

  Future<Uint8List> buildCustomWorksheet(
    CustomWorksheetData data, {
    bool highContrast = false,
  }) async {
    final fonts = await WorksheetPdfFonts.load();
    final pal = _WsPalette(highContrast: highContrast);
    final isGrade1 = _isEarlyGrade(data.grade);
    final bodySize = isGrade1 ? 14.0 : 12.0;
    final questionSize = isGrade1 ? 15.0 : 13.0;

    final document = _makeDocument(fonts);
    document.addPage(
      _makePage(build: (context) {
        final children = <pw.Widget>[
          _brandedHeader(pal, data.grade, data.subject, data.topic,
              subtitle: 'CUSTOM ASSIGNMENT'),
          pw.SizedBox(height: 12),
          _studentInfoRow(pal),
          pw.SizedBox(height: 16),
          _thinDivider(pal),
          pw.SizedBox(height: 14),
        ];

        // Render each teacher-authored question.
        for (var i = 0; i < data.questions.length; i++) {
          final q = data.questions[i];
          children.add(
            _customQuestionBlock(
              fonts: fonts,
              pal: pal,
              index: i + 1,
              question: q,
              bodySize: bodySize,
              questionSize: questionSize,
              showHindi: data.includeHindi,
              showSantali: data.includeSantali,
              showEnglish: data.includeEnglish,
            ),
          );
          if (i < data.questions.length - 1) {
            children.add(pw.SizedBox(height: 18));
          }
        }

        children.add(pw.Spacer());
        children.add(_footer(pal, isCustom: true));
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: children,
        );
      }),
    );
    return document.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Shared PDF building blocks
  // ══════════════════════════════════════════════════════════════════════════

  pw.Document _makeDocument(WorksheetPdfFonts fonts) {
    return pw.Document(
      theme: pw.ThemeData.withFont(fontFallback: fonts.fontFallback),
    );
  }

  pw.Page _makePage({required pw.Widget Function(pw.Context) build}) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 36),
      build: build,
    );
  }

  // ── Branded header ───────────────────────────────────────────────────────

  pw.Widget _brandedHeader(
    _WsPalette pal,
    String grade,
    String subject,
    String topic, {
    String subtitle = 'OFFLINE BILINGUAL WORKSHEET',
  }) {
    if (pal.highContrast) {
      // Low-ink: simple bold text, no background fill.
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: const pw.BorderSide(color: PdfColors.black, width: 2),
            bottom: const pw.BorderSide(color: PdfColors.black, width: 2),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              pw.Text('EduVaani',
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black)),
              pw.Spacer(),
              pw.Text(grade,
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.black)),
              pw.SizedBox(width: 8),
              pw.Text('|', style: const pw.TextStyle(color: PdfColors.black)),
              pw.SizedBox(width: 8),
              pw.Text(subject,
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.black)),
            ]),
            pw.SizedBox(height: 2),
            pw.Text(subtitle,
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.black,
                    letterSpacing: 1.2)),
            pw.SizedBox(height: 6),
            pw.Text(topic,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black)),
          ],
        ),
      );
    }

    // Colour header with brand teal background.
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: pw.BoxDecoration(
        color: pal.headerBg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Text('EduVaani',
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: pal.headerFg)),
            pw.Spacer(),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: PdfColors.white.withAlpha(40),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text('$grade  •  $subject',
                  style: pw.TextStyle(fontSize: 10, color: pal.headerFg)),
            ),
          ]),
          pw.SizedBox(height: 2),
          pw.Text(subtitle,
              style: pw.TextStyle(
                  fontSize: 9,
                  color: pal.headerSubFg,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 8),
          pw.Text(topic,
              style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: pal.headerFg)),
        ],
      ),
    );
  }

  // ── Name / Date / Class row ──────────────────────────────────────────────

  pw.Widget _studentInfoRow(_WsPalette pal) {
    const fields = ['Name / नाम', 'Date / तिथि', 'Class / कक्षा'];
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: pal.infoRowBorder, width: 0.7),
        ),
      ),
      child: pw.Row(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Row(children: [
                pw.Text(fields[i],
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Container(
                    height: 1,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                            color: pal.infoRowBorder, width: 0.5),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Language instruction box ─────────────────────────────────────────────

  pw.Widget _languageBox({
    required String heading,
    required String text,
    required WorksheetPdfFonts fonts,
    required _WsPalette pal,
    required double bodySize,
    required PdfColor bg,
    required PdfColor border,
    required PdfColor labelFg,
  }) {
    if (pal.highContrast) {
      // Low-ink: thin black border, no fill.
      return pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.8),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(heading,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: PdfColors.black)),
            pw.SizedBox(height: 6),
            fonts.scriptAwareText(text,
                style: pw.TextStyle(fontSize: bodySize)),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border(left: pw.BorderSide(color: border, width: 4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: border.withAlpha(30),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(heading,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: labelFg)),
          ),
          pw.SizedBox(height: 8),
          fonts.scriptAwareText(text,
              style: pw.TextStyle(fontSize: bodySize)),
        ],
      ),
    );
  }

  // ── Activity helpers ─────────────────────────────────────────────────────

  pw.Widget _questionLabel(
    WorksheetPdfFonts fonts,
    _WsPalette pal,
    double fontSize,
    String text,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(left: 4),
      child: fonts.scriptAwareText(text,
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: fontSize,
              color: pal.questionAccent)),
    );
  }

  /// Row of simple icon shapes (★ stars or ● circles) for counting exercises.
  /// In high-contrast mode uses outlined circles instead of filled stars.
  pw.Widget _iconShapeRow(_WsPalette pal,
      {required int count, required String shape}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: List.generate(count, (i) {
        if (i > 0) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10),
            child: _singleShape(pal, shape),
          );
        }
        return _singleShape(pal, shape);
      }),
    );
  }

  pw.Widget _singleShape(_WsPalette pal, String shape) {
    if (pal.highContrast) {
      // Low-ink: outlined circle.
      return pw.Container(
        width: 32,
        height: 32,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: PdfColors.black, width: 1.5),
        ),
      );
    }
    // Colour mode: filled star/circle via Unicode glyph.
    final glyph = shape == 'star' ? '★' : '●';
    return pw.Text(glyph,
        style: pw.TextStyle(fontSize: 30, color: pal.activityIconFg));
  }

  pw.Widget _answerLine(_WsPalette pal, String prompt) {
    return pw.Row(children: [
      pw.Text(prompt,
          style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(width: 8),
      pw.Text('Answer:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(width: 6),
      pw.Expanded(
        child: pw.Container(
          height: 1,
          decoration: pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: pal.infoRowBorder)),
          ),
        ),
      ),
    ]);
  }

  pw.Widget _numberOptionRow(_WsPalette pal) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [3, 4, 5, 6].map((n) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(right: 14),
          child: pw.Container(
            width: 44,
            height: 44,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: pal.numberOptionBg,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: pal.numberOptionBorder, width: 1.2),
            ),
            child: pw.Text('$n',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  // ── Custom question block ────────────────────────────────────────────────

  pw.Widget _customQuestionBlock({
    required WorksheetPdfFonts fonts,
    required _WsPalette pal,
    required int index,
    required CustomQuestion question,
    required double bodySize,
    required double questionSize,
    required bool showHindi,
    required bool showSantali,
    required bool showEnglish,
  }) {
    final children = <pw.Widget>[];

    // Question number label.
    children.add(pw.Text('Question $index',
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: pal.questionAccent,
            letterSpacing: 0.5)));
    children.add(pw.SizedBox(height: 6));

    // Hindi box.
    if (showHindi && question.hindiText.isNotEmpty) {
      children.add(_languageBox(
        heading: 'Hindi',
        text: question.hindiText,
        fonts: fonts,
        pal: pal,
        bodySize: bodySize,
        bg: pal.hindiBoxBg,
        border: pal.hindiBoxBorder,
        labelFg: pal.hindiLabelFg,
      ));
      children.add(pw.SizedBox(height: 6));
    }

    // Santali box — label auto-translated content.
    if (showSantali && (question.santaliText?.isNotEmpty ?? false)) {
      final santaliLabel = question.isAiTranslated
          ? 'Santali  ⚠ AI-translated — review needed'
          : 'Santali';
      children.add(_languageBox(
        heading: santaliLabel,
        text: question.santaliText!,
        fonts: fonts,
        pal: pal,
        bodySize: bodySize,
        bg: pal.santaliBoxBg,
        border: pal.santaliBoxBorder,
        labelFg: pal.santaliLabelFg,
      ));
      children.add(pw.SizedBox(height: 6));
    }

    // English box.
    if (showEnglish && (question.englishText?.isNotEmpty ?? false)) {
      children.add(_languageBox(
        heading: 'English',
        text: question.englishText!,
        fonts: fonts,
        pal: pal,
        bodySize: bodySize,
        bg: pal.englishBoxBg,
        border: pal.englishBoxBorder,
        labelFg: pal.englishLabelFg,
      ));
      children.add(pw.SizedBox(height: 6));
    }

    // Activity space based on question type.
    if (question.questionType == 'count') {
      children.add(pw.SizedBox(height: 4));
      children.add(_iconShapeRow(pal, count: 5, shape: 'star'));
      children.add(pw.SizedBox(height: 8));
      children.add(_answerLine(pal, 'How many?'));
    } else if (question.questionType == 'circle') {
      children.add(pw.SizedBox(height: 4));
      children.add(_numberOptionRow(pal));
    } else {
      // Default: answer lines.
      children.add(pw.SizedBox(height: 6));
      children.add(_answerLine(pal, 'Answer:'));
      children.add(pw.SizedBox(height: 10));
      children.add(pw.Container(height: 1,
          decoration: pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: pal.infoRowBorder, width: 0.4)),
          )));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  // ── Shared small widgets ─────────────────────────────────────────────────

  pw.Widget _thinDivider(_WsPalette pal) {
    return pw.Container(
      height: 1,
      color: pal.sectionDivider.withAlpha(60),
    );
  }

  pw.Widget _footer(_WsPalette pal, {bool isCustom = false}) {
    final customLabel = isCustom ? ' — Custom Assignment' : '';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated locally by EduVaani$customLabel',
            style: pw.TextStyle(fontSize: 8, color: pal.footerFg)),
        pw.Text('No internet required',
            style: pw.TextStyle(fontSize: 8, color: pal.footerFg)),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static bool _isEarlyGrade(String grade) {
    final lower = grade.toLowerCase();
    return lower.contains('1') || lower.contains('kg') || lower.contains('pre');
  }
}
