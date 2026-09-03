class TranslationResult {
  const TranslationResult({
    required this.source,
    required this.output,
    required this.isPrototype,
    required this.matchedPhrase,
    this.note,
  });

  final String source;
  final String output;
  final bool isPrototype;
  final bool matchedPhrase;
  final String? note;
}

class ClassroomPhrase {
  const ClassroomPhrase({
    required this.hindi,
    required this.santali,
    required this.englishHint,
  });

  final String hindi;
  final String santali;
  final String englishHint;
}

/// Translation contract shared by the offline demo and a future ONNX model.
abstract class TranslationService {
  const TranslationService();

  static final TranslationService instance = MockTranslationService.instance;

  static List<ClassroomPhrase> get phrases => MockTranslationService.phrases;

  TranslationResult hindiToSantali(String input);
  TranslationResult santaliToHindi(String input);
}

/// Offline, dictionary-based Hindi ↔ Santali helper for the prototype.
/// This is not a neural model; unmatched text is marked clearly.
class MockTranslationService implements TranslationService {
  MockTranslationService._();
  static final MockTranslationService instance = MockTranslationService._();

  static const List<ClassroomPhrase> phrases = [
    ClassroomPhrase(
      hindi: 'बच्चों को दस वस्तुएँ दें और उन्हें एक-एक करके गिनने के लिए कहें।',
      santali: 'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱜᱮᱞ ᱜᱚᱴᱟᱝ ᱡᱤᱱᱤᱥ ᱮᱢᱟ ᱠᱚᱢ ᱟᱨ ᱢᱤᱫ-ᱢᱤᱫ ᱛᱮ ᱞᱮᱠᱷᱟ ᱪᱚ ᱠᱚᱢ᱾',
      englishHint: 'Give ten objects and ask children to count one by one.',
    ),
    ClassroomPhrase(
      hindi: 'बच्चों को अपनी किताब खोलने के लिए कहें।',
      santali: 'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱟᱠᱚᱣᱟᱜ ᱯᱚᱛᱚᱵ ᱠᱷᱩᱞᱟᱹᱣ ᱞᱟᱹᱜᱤᱫ ᱢᱮᱛᱟ ᱠᱚᱢ᱾',
      englishHint: 'Ask children to open their book.',
    ),
    ClassroomPhrase(
      hindi: 'दो और दो कितने होते हैं, बच्चों से पूछें।',
      santali: 'ᱵᱟᱨ ᱟᱨ ᱵᱟᱨ ᱛᱤᱱᱟᱹᱜ ᱦᱩᱭᱩᱜᱼᱟ, ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱠᱩᱞᱤ ᱠᱚᱢ᱾',
      englishHint: 'Ask children how much is two and two.',
    ),
    ClassroomPhrase(
      hindi: 'एक वाक्य बोलें और बच्चों से दोहराने को कहें।',
      santali: 'ᱢᱤᱫ ᱟᱹᱭᱠᱟᱹᱣ ᱢᱮ ᱟᱨ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱫᱩᱦᱲᱟᱹ ᱞᱟᱹᱜᱤᱫ ᱢᱮᱛᱟ ᱠᱚᱢ᱾',
      englishHint: 'Say a sentence and ask children to repeat.',
    ),
    ClassroomPhrase(
      hindi: 'शांत बैठो।',
      santali: 'ᱥᱟᱱᱛᱤ ᱛᱮ ᱫᱩᱲᱩᱵ ᱯᱮ᱾',
      englishHint: 'Sit quietly.',
    ),
    ClassroomPhrase(
      hindi: 'कृपया ध्यान से सुनो।',
      santali: 'ᱫᱟᱭᱟᱠᱟᱛᱮ ᱜᱚᱨ ᱥᱟᱶ ᱟᱸᱡᱚᱢ ᱯᱮ᱾',
      englishHint: 'Please listen carefully.',
    ),
    ClassroomPhrase(
      hindi: 'अपनी कॉपी खोलो।',
      santali: 'ᱟᱢᱟᱜ ᱠᱚᱯᱤ ᱠᱷᱩᱞᱟᱹᱣ ᱯᱮ᱾',
      englishHint: 'Open your notebook.',
    ),
    ClassroomPhrase(
      hindi: 'यह कितने हैं?',
      santali: 'ᱱᱚᱣᱟ ᱛᱤᱱᱟᱹᱜ ᱢᱮᱱᱟᱜᱼᱟ?',
      englishHint: 'How many are these?',
    ),
    ClassroomPhrase(
      hindi: 'बहुत अच्छा।',
      santali: 'ᱟᱹᱰᱤ ᱵᱟᱹᱲᱤᱡᱽ᱾',
      englishHint: 'Very good.',
    ),
    ClassroomPhrase(
      hindi: 'अब मिलकर गिनो।',
      santali: 'ᱱᱤᱛᱚᱜ ᱢᱤᱫ ᱥᱟᱶᱛᱮ ᱞᱮᱠᱷᱟ ᱯᱮ᱾',
      englishHint: 'Now count together.',
    ),
  ];

  static const Map<String, String> _hindiToSantaliWords = {
    'बच्चों': 'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ',
    'किताब': 'ᱯᱚᱛᱚᱵ',
    'कॉपी': 'ᱠᱚᱯᱤ',
    'गिनो': 'ᱞᱮᱠᱷᱟ',
    'गिनने': 'ᱞᱮᱠᱷᱟ',
    'खोलो': 'ᱠᱷᱩᱞᱟᱹᱣ',
    'सुनो': 'ᱟᱸᱡᱚᱢ',
    'बैठो': 'ᱫᱩᱲᱩᱵ',
    'दो': 'ᱵᱟᱨ',
    'दस': 'ᱜᱮᱞ',
    'एक': 'ᱢᱤᱫ',
    'कितने': 'ᱛᱤᱱᱟᱹᱜ',
    'अच्छा': 'ᱵᱟᱹᱲᱤᱡᱽ',
  };

  @override
  TranslationResult hindiToSantali(String input) {
    final source = input.trim();
    if (source.isEmpty) {
      return const TranslationResult(
        source: '',
        output: '',
        isPrototype: true,
        matchedPhrase: false,
        note: 'Type a Hindi classroom phrase to translate.',
      );
    }

    final exact = _findPhrase(source);
    if (exact != null) {
      return TranslationResult(
        source: source,
        output: exact.santali,
        isPrototype: true,
        matchedPhrase: true,
        note: exact.englishHint,
      );
    }

    final words = source.split(RegExp(r'\s+'));
    final translated = <String>[];
    var anyHit = false;
    for (final word in words) {
      final key = word.replaceAll(RegExp(r'[।?!,.]'), '');
      final mapped = _hindiToSantaliWords[key];
      if (mapped != null) {
        anyHit = true;
        translated.add(mapped);
      } else {
        translated.add(word);
      }
    }

    return TranslationResult(
      source: source,
      output: translated.join(' '),
      isPrototype: true,
      matchedPhrase: false,
      note: anyHit
          ? 'Partial word-level prototype. Unmapped words are kept in Hindi.'
          : 'No dictionary match. Add this phrase to the offline pack later.',
    );
  }

  @override
  TranslationResult santaliToHindi(String input) {
    final source = input.trim();
    if (source.isEmpty) {
      return const TranslationResult(
        source: '',
        output: '',
        isPrototype: true,
        matchedPhrase: false,
        note: 'Paste Ol Chiki text from a known classroom phrase.',
      );
    }
    for (final phrase in phrases) {
      if (_normalize(phrase.santali) == _normalize(source)) {
        return TranslationResult(
          source: source,
          output: phrase.hindi,
          isPrototype: true,
          matchedPhrase: true,
          note: phrase.englishHint,
        );
      }
    }
    return TranslationResult(
      source: source,
      output: source,
      isPrototype: true,
      matchedPhrase: false,
      note: 'No reverse dictionary match for this Santali text.',
    );
  }

  ClassroomPhrase? _findPhrase(String source) {
    final needle = _normalize(source);
    for (final phrase in phrases) {
      if (_normalize(phrase.hindi) == needle) return phrase;
    }
    ClassroomPhrase? best;
    for (final phrase in phrases) {
      final hindi = _normalize(phrase.hindi);
      if (needle.contains(hindi) || hindi.contains(needle)) {
        if (best == null || phrase.hindi.length > best.hindi.length) {
          best = phrase;
        }
      }
    }
    return best;
  }

  String _normalize(String value) {
    return value
        .replaceAll('[Prototype Santali Translation]', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('।', '')
        .trim();
  }
}
