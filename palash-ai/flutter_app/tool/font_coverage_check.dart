// ignore_for_file: avoid_print
// Dev-only helper: reports Unicode block coverage of the bundled worksheet
// fonts. Run with: dart run tool/font_coverage_check.dart
import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:pdf/pdf.dart' show TtfParser;

void main() {
  const fonts = [
    'assets/fonts/NotoSansOlChiki-Regular.ttf',
    'assets/fonts/NotoSansOlChiki-Bold.ttf',
    'assets/fonts/NotoSansDevanagari-Regular.ttf',
    'assets/fonts/NotoSansDevanagari-Bold.ttf',
  ];
  const probes = {
    'U+25CF (●)': 0x25CF,
    'U+25A0 (■)': 0x25A0,
    'U+2605 (★)': 0x2605,
    'U+0020 space': 0x20,
    'U+0964 danda': 0x964,
    'U+1C50 OlChiki 0': 0x1C50,
    'U+1C7F OlChiki punct': 0x1C7F,
  };
  for (final path in fonts) {
    final bytes = File(path).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    final parser = TtfParser(data);
    final ol = _count(parser, 0x1C50, 0x1C7F);
    final dv = _count(parser, 0x0900, 0x097F);
    final latin = _count(parser, 0x20, 0x7E);
    final buf = StringBuffer();
    probes.forEach((label, rune) {
      buf.write('$label=${parser.charToGlyphIndexMap.containsKey(rune)} ');
    });
    print('$path: OlChiki=$ol/48 Deva=$dv/128 ASCII=$latin/95 | $buf');
  }
}

int _count(TtfParser parser, int start, int end) {
  var n = 0;
  for (var c = start; c <= end; c++) {
    if (parser.charToGlyphIndexMap.containsKey(c)) n++;
  }
  return n;
}
