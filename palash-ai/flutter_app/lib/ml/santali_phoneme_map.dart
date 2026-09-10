/// Santali (Ol Chiki) to Hindi (Devanagari) Phonetic Transliteration Map.
///
/// ============================================================================
/// LINGUISTIC NOTICE & REQUIRED MANUAL QA STEP:
/// ============================================================================
/// This phonetic mapping table is an engineered approximation (Option A) designed
/// to enable offline speech synthesis of Santali text using a pretrained Hindi
/// Text-To-Speech (TTS) acoustic model.
///
/// Santali (an Austroasiatic / Munda language) has distinct phonological features
/// that do not exist natively in Hindi (Indo-Aryan):
///   1. Checked consonants / Deglottalization:
///      Ol Chiki letters ᱜ (ag), ᱡ (aaj), ᱫ (ud), and ᱵ (ob) represent
///      unreleased glottalized pre-stops [kʼ, cʼ, tʼ, pʼ] in coda (word-final /
///      syllable-final) position. Hindi phonology lacks these checked stops.
///      Here, they are mapped to their voiced equivalents (ग, ज, द, ब) or
///      unreleased plosives with halant. When followed by ᱼ (ahad), they are
///      phonetically deglottalized into plain voiced plosives.
///   2. Open/Central Vowel Distinctions (Gaahlaa Tudag ᱹ):
///      Santali distinguishes open-mid back vowels from close-mid and central
///      vowels using the baseline dot (ᱹ). For instance, ᱟᱹ represents /ə/
///      (schwa), mapped here to Hindi अ, whereas ᱟ is /a/ (आ).
///   3. Aspiration Marker ᱷ:
///      In Ol Chiki, aspiration is written analytically as a consonant followed
///      by ᱷ (e.g. ᱛ+ᱷ = th, ᱠ+ᱷ = kh, ᱫ+ᱷ = dh). This module merges these
///      digraphs into the corresponding aspirated Devanagari consonants.
///
/// NOTE: This mapping must be formally reviewed and calibrated by a native
/// Santali speaker and linguist prior to production certification.
library;

/// Transliterates Ol Chiki (U+1C50–U+1C7F) text into a phonetically optimized
/// Devanagari string for Hindi TTS engines.
String santaliToHindiPhonemes(String santaliText) {
  if (santaliText.isEmpty) return '';

  final runes = santaliText.runes.toList();
  final buffer = StringBuffer();
  int i = 0;

  while (i < runes.length) {
    final code = runes[i];

    // Check if the current character is outside Ol Chiki range
    if (code < 0x1C50 || code > 0x1C7F) {
      buffer.writeCharCode(code);
      i++;
      continue;
    }

    // Handle Ol Chiki Digits (U+1C50 - U+1C59)
    if (code >= 0x1C50 && code <= 0x1C59) {
      // Map to Devanagari digits (U+0966 - U+096F)
      buffer.writeCharCode(0x0966 + (code - 0x1C50));
      i++;
      continue;
    }

    // Handle Punctuation
    if (code == 0x1C7E) {
      // ᱾ Mucaad (sentence final) -> Devanagari Danda ।
      buffer.write('।');
      i++;
      continue;
    }
    if (code == 0x1C7F) {
      // ᱿ Double Mucaad (section final) -> Devanagari Double Danda ॥
      buffer.write('॥');
      i++;
      continue;
    }

    // Check for aspiration digraphs: Consonant followed by ᱷ (U+1C77)
    if (i + 1 < runes.length && runes[i + 1] == 0x1C77) {
      final aspirated = _aspiratedConsonants[code];
      if (aspirated != null) {
        // Look ahead for vowel or modifiers on the aspirated consonant
        i += 2;
        i = _attachVowelOrHalant(runes, i, aspirated, buffer);
        continue;
      }
    }

    // Check for deglottalizer ᱼ (Ahad U+1C7C) on checked consonants
    if (i + 1 < runes.length && runes[i + 1] == 0x1C7C) {
      final plain = _deglottalizedConsonants[code];
      if (plain != null) {
        i += 2;
        i = _attachVowelOrHalant(runes, i, plain, buffer);
        continue;
      }
    }

    // Check for vowels
    if (_isOlChikiVowel(code)) {
      final independent = _independentVowels[code] ?? '';
      // Check if vowel is modified by Gaahlaa Tudag ᱹ (U+1C79)
      if (i + 1 < runes.length && runes[i + 1] == 0x1C79) {
        final modified = _modifiedVowels[code] ?? independent;
        buffer.write(modified);
        i += 2;
      } else {
        buffer.write(independent);
        i++;
      }
      i = _consumeNasalModifiers(runes, i, buffer);
      continue;
    }

    // Consonant
    final devConsonant = _singleConsonants[code];
    if (devConsonant != null) {
      i++;
      i = _attachVowelOrHalant(runes, i, devConsonant, buffer);
      continue;
    }

    // Modifiers without preceding base (standalone)
    if (code == 0x1C78 || code == 0x1C7A) {
      // ᱸ Mu Tudag / ᱺ Mu-Gaahlaa Tudag -> Candrabindu / Anusvara
      buffer.write('ं');
    } else if (code == 0x1C7B) {
      // ᱻ Relaa (lengthening) -> Avagraha
      buffer.write('ऽ');
    }

    i++;
  }

  return buffer.toString();
}

/// Checks whether [text] contains any Ol Chiki Unicode characters (U+1C50 to U+1C7F).
bool containsOlChiki(String text) {
  for (final code in text.runes) {
    if (code >= 0x1C50 && code <= 0x1C7F) return true;
  }
  return false;
}

// ── Private Internal Mapping Tables ──────────────────────────────────────────

bool _isOlChikiVowel(int code) {
  return code == 0x1C5A || // ᱚ LA  (/ɔ/)
      code == 0x1C5F || // ᱟ LAA (/a/)
      code == 0x1C64 || // ᱤ LI  (/i/)
      code == 0x1C69 || // ᱩ LU  (/u/)
      code == 0x1C6E || // ᱮ LE  (/e/)
      code == 0x1C73; // ᱳ LO  (/o/)
}

/// Independent Devanagari vowel representations.
const Map<int, String> _independentVowels = {
  0x1C5A: 'अ', // ᱚ -> अ (/ɔ/ approximated as short a)
  0x1C5F: 'आ', // ᱟ -> आ
  0x1C64: 'इ', // ᱤ -> इ
  0x1C69: 'उ', // ᱩ -> उ
  0x1C6E: 'ए', // ᱮ -> ए
  0x1C73: 'ओ', // ᱳ -> ओ
};

/// Vowels modified by Gaahlaa Tudag ᱹ (U+1C79).
/// Gaahlaa Tudag indicates a lowered / central vowel shift.
const Map<int, String> _modifiedVowels = {
  0x1C5A: 'ऑ', // ᱚᱹ -> /ɔ/ open-mid back vowel (approximated as ऑ)
  0x1C5F: 'अ', // ᱟᱹ -> /ə/ central vowel (schwa, approximated as short अ)
  0x1C64: 'ई', // ᱤᱹ -> /e/ higher front vowel
  0x1C69: 'उ', // ᱩᱹ -> /u/ central-back
  0x1C6E: 'ऐ', // ᱮᱹ -> /ɛ/ open-mid front vowel (approximated as ऐ)
  0x1C73: 'औ', // ᱳᱹ -> /o/
};

/// Dependent vowel signs (Matras) when attached to a consonant.
const Map<int, String> _dependentMatras = {
  0x1C5A: '', // ᱚ -> Inherent short vowel in Devanagari
  0x1C5F: 'ा', // ᱟ -> ा
  0x1C64: 'ि', // ᱤ -> ि
  0x1C69: 'ु', // ᱩ -> ु
  0x1C6E: 'े', // ᱮ -> े
  0x1C73: 'ो', // ᱳ -> ो
};

/// Modified dependent vowel signs (with Gaahlaa Tudag ᱹ).
const Map<int, String> _modifiedMatras = {
  0x1C5A: 'ॉ', // ᱚᱹ -> ॉ
  0x1C5F: '', // ᱟᱹ -> inherent schwa (no matra, natural /ə/)
  0x1C64: 'ी', // ᱤᱹ -> ी
  0x1C69: 'ु', // ᱩᱹ -> ु
  0x1C6E: 'ै', // ᱮᱹ -> ै
  0x1C73: 'ौ', // ᱳᱹ -> ौ
};

/// Single consonants (without aspiration marker).
const Map<int, String> _singleConsonants = {
  0x1C5B: 'त', // ᱛ AT
  0x1C5C: 'ग', // ᱜ AG (checked /k'/ in coda; voiced /g/ intervocalic)
  0x1C5D: 'ङ', // ᱝ ANG (/ŋ/)
  0x1C5E: 'ल', // ᱞ AL
  0x1C60: 'क', // ᱠ AAK
  0x1C61: 'ज', // ᱡ AAJ (checked /c'/ in coda; voiced /j/ intervocalic)
  0x1C62: 'म', // ᱢ AAM
  0x1C63: 'व', // ᱣ AAW (/w/)
  0x1C65: 'स', // ᱥ IS
  0x1C66: 'ह', // ᱦ IH
  0x1C67: 'ञ', // ᱧ INJ (/ɲ/)
  0x1C68: 'र', // ᱨ IR
  0x1C6A: 'च', // ᱪ UCH
  0x1C6B: 'द', // ᱫ UD (checked /t'/ in coda; voiced /d/ intervocalic)
  0x1C6C: 'ण', // ᱬ UNN (/ɳ/)
  0x1C6D: 'य', // ᱭ UY
  0x1C6F: 'प', // ᱯ EP
  0x1C70: 'ड', // ᱰ EDD (/ɖ/)
  0x1C71: 'न', // ᱱ EN
  0x1C72: 'ड़', // ᱲ ERR (/ɽ/ retroflex flap)
  0x1C74: 'ट', // ᱴ OTT
  0x1C75: 'ब', // ᱵ OB (checked /p'/ in coda; voiced /b/ intervocalic)
  0x1C76: 'वँ', // ᱶ OV (nasalized labial approximant /w̃/)
  0x1C77: 'ह', // ᱷ OH (aspiration marker / h)
};

/// Digraphs: Consonant + ᱷ (U+1C77 OH) forming aspirated consonants.
const Map<int, String> _aspiratedConsonants = {
  0x1C5B: 'थ', // ᱛ + ᱷ -> थ
  0x1C5C: 'घ', // ᱜ + ᱷ -> घ
  0x1C60: 'ख', // ᱠ + ᱷ -> ख
  0x1C61: 'झ', // ᱡ + ᱷ -> झ
  0x1C6A: 'छ', // ᱪ + ᱷ -> छ
  0x1C6B: 'ध', // ᱫ + ᱷ -> ध
  0x1C6F: 'फ', // ᱯ + ᱷ -> फ
  0x1C70: 'ढ', // ᱰ + ᱷ -> ढ
  0x1C74: 'ठ', // ᱴ + ᱷ -> ठ
  0x1C75: 'भ', // ᱵ + ᱷ -> भ
};

/// Deglottalized checked consonants (when followed by ᱼ AHAD U+1C7C).
const Map<int, String> _deglottalizedConsonants = {
  0x1C5C: 'ग', // ᱜ + ᱼ -> ग
  0x1C61: 'ज', // ᱡ + ᱼ -> ज
  0x1C6B: 'द', // ᱫ + ᱼ -> द
  0x1C75: 'ब', // ᱵ + ᱼ -> ब
};

/// Helper to attach matra or virama to a consonant base.
int _attachVowelOrHalant(
  List<int> runes,
  int nextIdx,
  String consonant,
  StringBuffer buffer,
) {
  if (nextIdx < runes.length && _isOlChikiVowel(runes[nextIdx])) {
    final vCode = runes[nextIdx];
    nextIdx++;
    // Check if vowel has Gaahlaa Tudag ᱹ (U+1C79)
    final bool isModified = nextIdx < runes.length && runes[nextIdx] == 0x1C79;
    if (isModified) nextIdx++;

    final matra = isModified
        ? (_modifiedMatras[vCode] ?? '')
        : (_dependentMatras[vCode] ?? '');

    buffer.write(consonant);
    buffer.write(matra);
  } else {
    // Consonant not followed by a vowel:
    // If it's followed by another consonant or end-of-word, add virama if in
    // middle of word or cluster; if end of word, keep clean consonant.
    buffer.write(consonant);
    if (nextIdx < runes.length &&
        !_isWhitespaceOrPunctuation(runes[nextIdx]) &&
        !_isOlChikiVowel(runes[nextIdx])) {
      // Next is another consonant -> create cluster with virama ्
      buffer.write('्');
    }
  }

  return _consumeNasalModifiers(runes, nextIdx, buffer);
}

int _consumeNasalModifiers(List<int> runes, int idx, StringBuffer buffer) {
  while (idx < runes.length) {
    final mod = runes[idx];
    if (mod == 0x1C78 || mod == 0x1C7A) {
      // ᱸ Mu Tudag / ᱺ Mu-Gaahlaa Tudag -> Anusvara
      buffer.write('ं');
      idx++;
    } else if (mod == 0x1C7B) {
      // ᱻ Relaa -> Avagraha
      buffer.write('ऽ');
      idx++;
    } else {
      break;
    }
  }
  return idx;
}

bool _isWhitespaceOrPunctuation(int code) {
  return code == 0x20 ||
      code == 0x09 ||
      code == 0x0A ||
      code == 0x0D ||
      code == 0x1C7E || // ᱾
      code == 0x1C7F || // ᱿
      code == 0x2E || // .
      code == 0x2C || // ,
      code == 0x3F || // ?
      code == 0x21; // !
}
