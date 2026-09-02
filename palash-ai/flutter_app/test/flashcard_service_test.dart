import 'package:flutter_app/services/flashcard_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flashcard generator creates ten cards and a PDF', () async {
    expect(FlashcardService.cards, hasLength(10));
    final bytes = await FlashcardService().buildPdf();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
