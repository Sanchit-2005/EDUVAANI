import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class Flashcard {
  const Flashcard({
    required this.number,
    required this.hindiWord,
    required this.santaliWord,
  });

  final int number;
  final String hindiWord;
  final String santaliWord;
}

class FlashcardService {
  static const cards = <Flashcard>[
    Flashcard(number: 1, hindiWord: 'एक', santaliWord: 'ᱢᱤᱫ'),
    Flashcard(number: 2, hindiWord: 'दो', santaliWord: 'ᱵᱟᱨ'),
    Flashcard(number: 3, hindiWord: 'तीन', santaliWord: '[Prototype Santali]'),
    Flashcard(number: 4, hindiWord: 'चार', santaliWord: '[Prototype Santali]'),
    Flashcard(number: 5, hindiWord: 'पाँच', santaliWord: '[Prototype Santali]'),
    Flashcard(number: 6, hindiWord: 'छह', santaliWord: '[Prototype Santali]'),
    Flashcard(number: 7, hindiWord: 'सात', santaliWord: '[Prototype Santali]'),
    Flashcard(number: 8, hindiWord: 'आठ', santaliWord: '[Prototype Santali]'),
    Flashcard(number: 9, hindiWord: 'नौ', santaliWord: '[Prototype Santali]'),
    Flashcard(number: 10, hindiWord: 'दस', santaliWord: 'ᱜᱮᱞ'),
  ];

  Future<Uint8List> buildPdf() async {
    final document = pw.Document();
    for (final group in _chunks(cards, 4)) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (_) => pw.GridView(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            children: group.map(_card).toList(),
          ),
        ),
      );
    }
    return document.save();
  }

  pw.Widget _card(Flashcard card) => pw.Container(
    margin: const pw.EdgeInsets.all(8),
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue)),
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('${card.number}', style: pw.TextStyle(fontSize: 54, fontWeight: pw.FontWeight.bold)),
        pw.Text('Hindi: ${card.hindiWord}'),
        pw.Text('Santali: ${card.santaliWord}'),
        pw.Text(List.filled(card.number, '●').join(' '), style: const pw.TextStyle(fontSize: 15)),
      ],
    ),
  );

  Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
    for (var index = 0; index < values.length; index += size) {
      yield values.sublist(index, index + size > values.length ? values.length : index + size);
    }
  }
}
