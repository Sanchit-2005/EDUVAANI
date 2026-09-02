import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

/// Builds worksheets entirely on the device. No API call is made.
class WorksheetService {
  Future<Uint8List> buildBilingualWorksheet(WorksheetData data) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'EduVaani',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('OFFLINE BILINGUAL WORKSHEET'),
            pw.Divider(),
            pw.Text('${data.grade} | ${data.subject}'),
            pw.SizedBox(height: 8),
            pw.Text(
              data.topic,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 22),
            _section('Hindi instruction', data.hindiInstruction),
            pw.SizedBox(height: 14),
            _section('Santali instruction (prototype)', data.santaliInstruction),
            pw.SizedBox(height: 22),
            pw.Text(
              '1. Count the objects. / वस्तुओं को गिनो।',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 14),
            pw.Text('●   ●   ●   ●   ●', style: const pw.TextStyle(fontSize: 28)),
            pw.SizedBox(height: 12),
            pw.Text('How many objects? Answer: __________'),
            pw.SizedBox(height: 28),
            pw.Text(
              '2. Circle the correct number. / सही संख्या पर गोला लगाओ।',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 14),
            pw.Text('3      4      5      6'),
            pw.Spacer(),
            pw.Text('Generated locally by EduVaani - no internet required.'),
          ],
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _section(String heading, String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(heading, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(text),
        ],
      ),
    );
  }
}
