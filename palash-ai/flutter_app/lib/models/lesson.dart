import 'package:flutter/material.dart';

class Lesson {
  static const prototypeSantaliMarker = '[Prototype Santali Translation]';
  static const santaliUnverified = 'unverified';
  static const santaliVerified = 'verified';

  final int? id;
  final String grade;
  final String subject;
  final String topic;
  final String learningOutcome;
  final String hindiInstruction;
  final String? santaliTranslation;
  final bool isPrototypeTranslation;

  /// Ordered position within this grade and subject sequence.
  final int sequenceNumber;

  /// Intended teacher-facing activity duration.
  final int durationMinutes;

  /// [santaliVerified] only after a fluent Santali reviewer approves it.
  final String santaliQualityStatus;

  bool get needsSantaliReview =>
      santaliTranslation != null && santaliQualityStatus != santaliVerified;

  bool get isQuickActivity => durationMinutes <= 5;

  String get durationLabel =>
      isQuickActivity ? 'Quick Activity ($durationMinutes min)' : 'Full Lesson ($durationMinutes min)';

  IconData get topicIcon {
    final normalized = topic.toLowerCase();
    if (normalized.contains('count') || normalized.contains('addition') || normalized.contains('place')) {
      return Icons.calculate_rounded;
    }
    if (normalized.contains('letter')) return Icons.abc_rounded;
    if (normalized.contains('listen') || normalized.contains('speak')) {
      return Icons.record_voice_over_rounded;
    }
    if (normalized.contains('word') || normalized.contains('read')) {
      return Icons.menu_book_rounded;
    }
    return Icons.auto_stories_rounded;
  }

  Color get subjectColor => subject.toLowerCase().contains('numeracy')
      ? const Color(0xFF2563EB)
      : const Color(0xFF7C3AED);

  Lesson({
    this.id,
    required this.grade,
    required this.subject,
    required this.topic,
    required this.learningOutcome,
    required this.hindiInstruction,
    this.santaliTranslation,
    this.isPrototypeTranslation = false,
    this.sequenceNumber = 1,
    this.durationMinutes = 20,
    this.santaliQualityStatus = santaliUnverified,
  });

  /// Removes internal prototype markers before content reaches a teacher.
  static String? sanitizeSantaliTranslation(String? value) {
    if (value == null) return null;

    final sanitized = value
        .replaceAll(prototypeSantaliMarker, '')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    return sanitized.isEmpty ? null : sanitized;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'grade': grade,
      'subject': subject,
      'topic': topic,
      'learningOutcome': learningOutcome,
      'hindiInstruction': hindiInstruction,
      'santaliTranslation': sanitizeSantaliTranslation(santaliTranslation),
      'isPrototypeTranslation': isPrototypeTranslation ? 1 : 0,
      'sequenceNumber': sequenceNumber,
      'durationMinutes': durationMinutes,
      'santaliQualityStatus': santaliQualityStatus,
    };
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'],
      grade: map['grade'],
      subject: map['subject'],
      topic: map['topic'],
      learningOutcome: map['learningOutcome'],
      hindiInstruction: map['hindiInstruction'],
      santaliTranslation: sanitizeSantaliTranslation(map['santaliTranslation']),
      isPrototypeTranslation: map['isPrototypeTranslation'] == 1,
      sequenceNumber: map['sequenceNumber'] as int? ?? 1,
      durationMinutes: map['durationMinutes'] as int? ?? 20,
      santaliQualityStatus:
          map['santaliQualityStatus'] as String? ?? santaliUnverified,
    );
  }
}
