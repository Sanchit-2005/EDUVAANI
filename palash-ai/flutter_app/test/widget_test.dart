import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/translation_service.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EduVaaniApp());
    expect(find.text('EduVaani'), findsWidgets);
  });

  test('Hindi phrase maps to Santali prototype', () {
    final result = TranslationService.instance.hindiToSantali('शांत बैठो।');
    expect(result.matchedPhrase, isTrue);
    expect(result.output, isNotEmpty);
    expect(result.isPrototype, isTrue);
  });

  test('Santali phrase maps back to Hindi', () {
    const santali = 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾';
    final result = TranslationService.instance.santaliToHindi(santali);
    expect(result.matchedPhrase, isTrue);
    expect(result.output, 'शांत बैठो।');
  });
}
