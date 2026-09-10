import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/ml/asr_fuzzy_matcher.dart';

void main() {
  group('ClassroomCommandFuzzyMatcher', () {
    late ClassroomCommandFuzzyMatcher matcher;

    setUp(() {
      matcher = ClassroomCommandFuzzyMatcher();
    });

    test('Exact matches pass through and flag as match', () {
      final res = matcher.matchCommand('नमस्ते');
      expect(res.wasMatchApplied, isTrue);
      expect(res.correctedTranscript, 'नमस्ते');
      expect(res.similarityScore, 1.0);
    });

    test('Short word vowel/coda errors are corrected', () {
      expect(matcher.matchCommand('रुकुर').correctedTranscript, 'रुको');
      expect(matcher.matchCommand('रुक').correctedTranscript, 'रुको');
      expect(matcher.matchCommand('लिख').correctedTranscript, 'लिखो');
      expect(matcher.matchCommand('बैठ').correctedTranscript, 'बैठो');
      expect(matcher.matchCommand('सुनुक').correctedTranscript, 'सुनो');
    });

    test('Spurious whitespace inserted by CTC is healed for single-word targets', () {
      expect(matcher.matchCommand('खो लो').correctedTranscript, 'खोलो');
      expect(matcher.matchCommand('न बस्ते').correctedTranscript, 'नमस्ते');
    });

    test('Multi-word classroom phrases near-misses are corrected', () {
      expect(matcher.matchCommand('शांत बैठ हो').correctedTranscript, 'शांत बैठो');
      expect(matcher.matchCommand('शानत बैठो').correctedTranscript, 'शांत बैठो');
      expect(matcher.matchCommand('अपनी कपी खो लो').correctedTranscript, 'अपनी कॉपी खोलो');
      expect(matcher.matchCommand('अपनी कपी खोलो').correctedTranscript, 'अपनी कॉपी खोलो');
    });

    test('Long utterances (>4 tokens) pass through without modification', () {
      const longSentence = 'आज हम सब मिलकर अपनी हिंदी की किताब पढ़ेंगे';
      final res = matcher.matchCommand(longSentence);
      expect(res.wasMatchApplied, isFalse);
      expect(res.correctedTranscript, longSentence);
    });

    test('Non-command words ending in नो / लो do NOT falsely fire', () {
      final safeWords = [
        'मानो', 'जानो', 'तानो', 'गहनों', 'कानों', 'बहनों', 'दुकानों', 'मकानों', 'दीनो', 'बनो',
        'चलो', 'डालो', 'पीलो', 'झूलो', 'फलों', 'फूलों', 'दिलों', 'तालों', 'बादलों', 'तोलों',
        'धोलो', 'चुनो', 'गुनो', 'मीठो', 'उठो', 'रूठो', 'चखो', 'रखो', 'आंखों',
      ];
      for (final word in safeWords) {
        final res = matcher.matchCommand(word);
        expect(
          res.wasMatchApplied,
          isFalse,
          reason: 'Expected "$word" to pass through safely without false correction, but got "${res.correctedTranscript}"',
        );
      }
    });

    test('Related standalone commands बोलो and खेलो resolve to themselves', () {
      expect(matcher.matchCommand('बोलो').correctedTranscript, 'बोलो');
      expect(matcher.matchCommand('खेलो').correctedTranscript, 'खेलो');
    });
  });
}
