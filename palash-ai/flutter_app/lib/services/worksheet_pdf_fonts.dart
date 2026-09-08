import 'dart:developer' as dev;
import 'dart:typed_data' show ByteData;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:pdf/widgets.dart' as pw;

/// Ol Chiki (Santali) Unicode block: U+1C50–U+1C7F.
const int olChikiBlockStart = 0x1C50;
const int olChikiBlockEnd = 0x1C7F;

/// Devanagari (Hindi) Unicode block: U+0900–U+097F.
const int devanagariBlockStart = 0x0900;
const int devanagariBlockEnd = 0x097F;

/// Raised when the bundled script fonts cannot be loaded or do not actually
/// cover the scripts the worksheet needs. Always carries a teacher/developer
/// readable message — a missing Santali font must never silently degrade into
/// tofu boxes on a printed worksheet.
class WorksheetFontException implements Exception {
  const WorksheetFontException(this.message);

  final String message;

  @override
  String toString() => 'WorksheetFontException: $message';
}

/// Loads, validates and caches the script fonts used by the worksheet PDF
/// engine.
///
/// Two font families are bundled (see `assets/fonts/` and `pubspec.yaml`):
///  * Noto Sans Ol Chiki — Santali text (Ol Chiki script, U+1C50–U+1C7F).
///    The pdf package's default Helvetica font has no glyphs for this range,
///    which is why Santali used to render as empty boxes.
///  * Noto Sans Devanagari — Hindi text (U+0900–U+097F).
///
/// Latin text and digits stay on the pdf package's default Helvetica font.
///
/// The loader validates at runtime that the Ol Chiki font really covers the
/// Ol Chiki block (digits and a minimum number of letters) and throws a
/// [WorksheetFontException] with an actionable message otherwise, instead of
/// letting the PDF render placeholders.
class WorksheetPdfFonts {
  WorksheetPdfFonts._({
    required this.olChiki,
    required this.olChikiBold,
    required this.devanagari,
    required this.devanagariBold,
  });

  static const _olChikiRegularAsset =
      'assets/fonts/NotoSansOlChiki-Regular.ttf';
  static const _olChikiBoldAsset = 'assets/fonts/NotoSansOlChiki-Bold.ttf';
  static const _devanagariRegularAsset =
      'assets/fonts/NotoSansDevanagari-Regular.ttf';
  static const _devanagariBoldAsset =
      'assets/fonts/NotoSansDevanagari-Bold.ttf';

  static Future<WorksheetPdfFonts>? _instanceFuture;

  final pw.Font olChiki;
  final pw.Font olChikiBold;
  final pw.Font devanagari;
  final pw.Font devanagariBold;

  /// Fallback chain for the document theme. Any rune that the primary font
  /// (Helvetica) cannot render is retried against these fonts in order, so
  /// stray Ol Chiki/Devanagari text routed outside [scriptAwareSpan] still
  /// renders instead of turning into tofu boxes.
  List<pw.Font> get fontFallback => [olChiki, devanagari];

  /// Loads and validates the fonts once and reuses the same instances for
  /// every later PDF build. Failures are not cached — a retry re-attempts
  /// the load (e.g. after a hot reload or a fixed asset bundle).
  static Future<WorksheetPdfFonts> load() {
    final pending = _instanceFuture;
    if (pending != null) return pending;
    final future = _load();
    _instanceFuture = future;
    // Only successful loads stay cached; drop the future on error.
    future.then(
      (_) {},
      onError: (_) {
        if (identical(_instanceFuture, future)) _instanceFuture = null;
      },
    );
    return future;
  }

  /// Clears the cache so the next [load] re-reads the assets. Test helper.
  static void reset() => _instanceFuture = null;

  static Future<WorksheetPdfFonts> _load() async {
    final olChikiData = await _loadAsset(
      _olChikiRegularAsset,
      'Santali (Ol Chiki)',
    );
    final olChikiBoldData = await _loadAsset(
      _olChikiBoldAsset,
      'Santali (Ol Chiki) bold',
    );
    final devanagariData = await _loadAsset(
      _devanagariRegularAsset,
      'Hindi (Devanagari)',
    );
    final devanagariBoldData = await _loadAsset(
      _devanagariBoldAsset,
      'Hindi (Devanagari) bold',
    );

    assertCoversOlChiki(_parse(olChikiData), _olChikiRegularAsset);
    assertCoversOlChiki(_parse(olChikiBoldData), _olChikiBoldAsset);
    assertCoversDevanagari(
      _parse(devanagariData),
      _devanagariRegularAsset,
    );
    assertCoversDevanagari(
      _parse(devanagariBoldData),
      _devanagariBoldAsset,
    );

    final fonts = WorksheetPdfFonts._(
      olChiki: pw.Font.ttf(olChikiData.data),
      olChikiBold: pw.Font.ttf(olChikiBoldData.data),
      devanagari: pw.Font.ttf(devanagariData.data),
      devanagariBold: pw.Font.ttf(devanagariBoldData.data),
    );
    _debugLog(
      'Script fonts ready: Ol Chiki block coverage '
      '${_countCoverage(_parse(olChikiData), olChikiBlockStart, olChikiBlockEnd)}/48 '
      'codepoints, Devanagari block coverage '
      '${_countCoverage(_parse(devanagariData), devanagariBlockStart, devanagariBlockEnd)}/128 '
      'codepoints',
    );
    return fonts;
  }

  static Future<_FontAssetData> _loadAsset(String path, String label) async {
    try {
      final data = await rootBundle.load(path);
      if (data.lengthInBytes < 12) {
        throw WorksheetFontException(
          '$label font asset "$path" is only ${data.lengthInBytes} bytes — '
          'the file is truncated or corrupted. Santali/Hindi text cannot be '
          'rendered. Restore the font file (see assets/fonts/) and rebuild.',
        );
      }
      final magic = data.getUint32(0);
      const truetypeMagic = 0x00010000;
      const opentypeMagic = 0x4F54544F; // 'OTTO'
      if (magic != truetypeMagic && magic != opentypeMagic) {
        throw WorksheetFontException(
          '$label font asset "$path" is not a TrueType/OpenType font '
          '(unexpected magic 0x${magic.toRadixString(16)}). The PDF engine '
          'cannot embed it. Replace the file with the original Noto font.',
        );
      }
      return _FontAssetData(path, data);
    } on WorksheetFontException {
      rethrow;
    } catch (error) {
      throw WorksheetFontException(
        '$label font asset "$path" could not be read: $error. Bundled fonts '
        'are declared in pubspec.yaml — run "flutter pub get" and rebuild the '
        'app so the asset bundle is refreshed. Without this font, '
        'Santali/Hindi worksheet text renders as empty boxes.',
      );
    }
  }

  /// Asserts the font actually maps the Ol Chiki block. A load that "works"
  /// but has no Ol Chiki glyphs is exactly the silent-tofu failure mode this
  /// guard exists to prevent.
  @visibleForTesting
  static void assertCoversOlChiki(TtfParser parser, String path) {
    final coverage =
        _countCoverage(parser, olChikiBlockStart, olChikiBlockEnd);
    if (coverage < 40) {
      throw WorksheetFontException(
        'The bundled Santali font "$path" covers only $coverage of the 48 '
        'Ol Chiki codepoints (U+1C50–U+1C7F). Santali worksheet text would '
        'render as empty boxes. Bundle the real "Noto Sans Ol Chiki" font '
        '(Google Fonts, SIL Open Font License) and rebuild.',
      );
    }
    final missingDigits = <int>[
      for (var c = olChikiBlockStart; c < olChikiBlockStart + 10; c++)
        if (!parser.charToGlyphIndexMap.containsKey(c)) c,
    ];
    if (missingDigits.isNotEmpty) {
      throw WorksheetFontException(
        'The bundled Santali font "$path" is missing Ol Chiki digits '
        '${missingDigits.map((c) => 'U+${c.toRadixString(16)}').join(', ')}. '
        'Number work in Santali would render as boxes. Bundle the real '
        '"Noto Sans Ol Chiki" font and rebuild.',
      );
    }
  }

  @visibleForTesting
  static void assertCoversDevanagari(TtfParser parser, String path) {
    final coverage =
        _countCoverage(parser, devanagariBlockStart, devanagariBlockEnd);
    if (coverage < 100) {
      throw WorksheetFontException(
        'The bundled Hindi font "$path" covers only $coverage Devanagari '
        'codepoints in U+0900–U+097F (a full font maps ~120+). Hindi '
        'worksheet text would render as empty boxes. Bundle the real '
        '"Noto Sans Devanagari" font and rebuild.',
      );
    }
  }

  /// Parses the TTF defensively: [TtfParser]'s own corruption checks are
  /// `assert`s, which vanish in release builds, so corrupt files must be
  /// caught here instead.
  static TtfParser _parse(_FontAssetData asset) {
    try {
      return TtfParser(asset.data);
    } catch (error) {
      throw WorksheetFontException(
        'The font at "${asset.path}" could not be parsed as a TrueType '
        'font: $error. The file is corrupted — replace it with the original '
        'Noto font and rebuild.',
      );
    }
  }

  /// Number of mapped codepoints inside [start, end] for this font.
  static int _countCoverage(TtfParser parser, int start, int end) {
    var count = 0;
    for (var c = start; c <= end; c++) {
      if (parser.charToGlyphIndexMap.containsKey(c)) count++;
    }
    return count;
  }

  // ── Script-aware text runs ──────────────────────────────────────────────

  /// Splits [text] into runs by script and builds a [pw.TextSpan] tree that
  /// renders each run with the matching font:
  ///  * Ol Chiki (U+1C50–U+1C7F) → Noto Sans Ol Chiki
  ///  * Devanagari (U+0900–U+097F) → Noto Sans Devanagari
  ///  * everything else (English, digits, punctuation) → default font
  ///
  /// Bold styling is honoured per run via the matching bold font.
  pw.TextSpan scriptAwareSpan(String text, {pw.TextStyle? style}) {
    if (text.isEmpty) return pw.TextSpan(text: '', style: style);

    final runs = <({String text, _Script script})>[];
    var currentText = StringBuffer();
    _Script? currentScript;
    for (final rune in text.runes) {
      final script = _scriptOf(rune);
      if (currentScript != null && script != currentScript) {
        runs.add((text: currentText.toString(), script: currentScript));
        currentText = StringBuffer();
      }
      currentScript = script;
      currentText.writeCharCode(rune);
    }
    if (currentText.isNotEmpty && currentScript != null) {
      runs.add((text: currentText.toString(), script: currentScript));
    }

    // Fast path: single Latin run needs no font override at all.
    if (runs.length == 1 && runs.first.script == _Script.latin) {
      return pw.TextSpan(text: text, style: style);
    }

    return pw.TextSpan(
      style: style,
      children: [
        for (final run in runs)
          pw.TextSpan(
            text: run.text,
            style: _styleForScript(run.script, style),
          ),
      ],
    );
  }

  /// Renders [text] with per-script fonts as a flowing rich-text widget.
  pw.RichText scriptAwareText(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    bool softWrap = true,
  }) {
    return pw.RichText(
      text: scriptAwareSpan(text, style: style),
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }

  pw.TextStyle? _styleForScript(_Script script, pw.TextStyle? style) {
    switch (script) {
      case _Script.latin:
        return null;
      case _Script.olChiki:
        return (style ?? const pw.TextStyle()).copyWith(
          fontNormal: olChiki,
          fontBold: olChikiBold,
          fontItalic: olChiki,
          fontBoldItalic: olChikiBold,
        );
      case _Script.devanagari:
        return (style ?? const pw.TextStyle()).copyWith(
          fontNormal: devanagari,
          fontBold: devanagariBold,
          fontItalic: devanagari,
          fontBoldItalic: devanagariBold,
        );
    }
  }

  static _Script _scriptOf(int rune) {
    if (rune >= olChikiBlockStart && rune <= olChikiBlockEnd) {
      return _Script.olChiki;
    }
    if (rune >= devanagariBlockStart && rune <= devanagariBlockEnd) {
      return _Script.devanagari;
    }
    // Devanagari Extended and Vedic Extensions still need a Devanagari font.
    if (rune >= 0xA8E0 && rune <= 0xA8FF) return _Script.devanagari;
    if (rune >= 0x1CD0 && rune <= 0x1CFF) return _Script.devanagari;
    return _Script.latin;
  }

  static void _debugLog(String message) {
    if (kDebugMode) dev.log(message, name: 'WorksheetPdfFonts');
  }
}

enum _Script { latin, devanagari, olChiki }

class _FontAssetData {
  const _FontAssetData(this.path, this.data);

  final String path;
  final ByteData data;
}
