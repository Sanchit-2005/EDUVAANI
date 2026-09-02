import 'package:flutter_app/services/worksheet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
