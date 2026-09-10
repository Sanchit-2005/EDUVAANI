import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/ml/santali_phoneme_map.dart';

void main() {
  group('Santali (Ol Chiki) -> Hindi Phoneme Mapping Tests', () {
    test('Independent vowels map accurately', () {
      expect(santaliToHindiPhonemes('ᱚ'), 'अ');
      expect(santaliToHindiPhonemes('ᱟ'), 'आ');
      expect(santaliToHindiPhonemes('ᱤ'), 'इ');
      expect(santaliToHindiPhonemes('ᱩ'), 'उ');
      expect(santaliToHindiPhonemes('ᱮ'), 'ए');
      expect(santaliToHindiPhonemes('ᱳ'), 'ओ');
    });

    test('Modified vowels with Gaahlaa Tudag (central/open shifts)', () {
      expect(santaliToHindiPhonemes('ᱚᱹ'), 'ऑ');
      expect(santaliToHindiPhonemes('ᱟᱹ'), 'अ');
      expect(santaliToHindiPhonemes('ᱮᱹ'), 'ऐ');
    });

    test('Consonant with following vowel forms correct Devanagari syllable', () {
      // ᱥ (s) + ᱮ (e) -> से
      expect(santaliToHindiPhonemes('ᱥᱮ'), 'से');
      // ᱢ (m) + ᱮ (e) -> मे
      expect(santaliToHindiPhonemes('ᱢᱮ'), 'मे');
      // ᱛ (t) + ᱮ (e) -> ते
      expect(santaliToHindiPhonemes('ᱛᱮ'), 'ते');
      // ᱠ (k) + ᱟ (aa) -> का
      expect(santaliToHindiPhonemes('ᱠᱟ'), 'का');
      // ᱫ (d) + ᱩ (u) -> दु
      expect(santaliToHindiPhonemes('ᱫᱩ'), 'दु');
    });

    test('Aspirated digraphs (Consonant + ᱷ) map to aspirated Hindi consonants', () {
      // ᱛ (t) + ᱷ (h) -> थ
      expect(santaliToHindiPhonemes('ᱛᱷ'), 'थ');
      // ᱠ (k) + ᱷ (h) -> ख
      expect(santaliToHindiPhonemes('ᱠᱷ'), 'ख');
      // ᱪ (c) + ᱷ (h) -> छ
      expect(santaliToHindiPhonemes('ᱪᱷ'), 'छ');
      // ᱫ (d) + ᱷ (h) -> ध
      expect(santaliToHindiPhonemes('ᱫᱷ'), 'ध');
      // ᱯ (p) + ᱷ (h) -> फ
      expect(santaliToHindiPhonemes('ᱯᱷ'), 'फ');
      // ᱜ (g) + ᱷ (h) -> घ
      expect(santaliToHindiPhonemes('ᱜᱷ'), 'घ');
      // ᱵ (b) + ᱷ (h) -> भ
      expect(santaliToHindiPhonemes('ᱵᱷ'), 'भ');

      // With following vowel:
      // ᱛᱷ (th) + ᱮ (e) -> थे
      expect(santaliToHindiPhonemes('ᱛᱷᱮ'), 'थे');
    });

    test('Consonant clusters insert halant / virama', () {
      // ᱱ (n) + ᱛ (t) -> न् + त
      expect(santaliToHindiPhonemes('ᱱᱛ'), 'न्त');
      // ᱥ (s) + ᱠ (k) + ᱩ (u) + ᱞ (l) -> स्कूल
      expect(santaliToHindiPhonemes('ᱥᱠᱩᱞ'), 'स्कुल');
    });

    test('Nasal modifier (Mu Tudag ᱸ) attaches Anusvara', () {
      // ᱚᱸ -> अं
      expect(santaliToHindiPhonemes('ᱚᱸ'), 'अं');
      // ᱢᱟᱸ -> मां
      expect(santaliToHindiPhonemes('ᱢᱟᱸ'), 'मां');
    });

    test('Santali punctuation and digits map to Devanagari equivalents', () {
      // ᱾ -> ।
      expect(santaliToHindiPhonemes('᱾'), '।');
      // ᱿ -> ॥
      expect(santaliToHindiPhonemes('᱿'), '॥');
      // ᱐ ᱑ ᱒ ᱓ ᱔ ᱕ ᱖ ᱗ ᱘ ᱙ -> ० १ २ ३ ४ ५ ६ ७ ८ ९
      expect(santaliToHindiPhonemes('᱐᱑᱒᱓᱔᱕᱖᱗᱘᱙'), '०१२३४५६७८९');
    });

    test('Full classroom phrases transliterate cleanly for TTS', () {
      // ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾
      final result1 = santaliToHindiPhonemes('ᱥᱟᱹᱱᱛᱤ ᱛᱮ ᱥᱮᱱ ᱢᱮ ᱾');
      expect(result1, contains('से'));
      expect(result1, contains('मे'));
      expect(result1, endsWith('।'));

      // ᱫᱩᱲᱩᱵ ᱢᱮ ᱾ (Sit down)
      // ᱫ (d) + ᱩ (u) = दु, ᱲ (R) + ᱩ (u) = ड़ु, ᱵ (b) = ब
      final result2 = santaliToHindiPhonemes('ᱫᱩᱲᱩᱵ ᱢᱮ ᱾');
      expect(result2, 'दुड़ुब मे ।');
    });

    test('containsOlChiki correctly detects presence of Ol Chiki script', () {
      expect(containsOlChiki('ᱥᱟᱹᱱᱛᱤ'), isTrue);
      expect(containsOlChiki('शांत बैठो'), isFalse);
      expect(containsOlChiki('Hello 123'), isFalse);
      expect(containsOlChiki('Mixed ᱥ text'), isTrue);
    });
  });
}
