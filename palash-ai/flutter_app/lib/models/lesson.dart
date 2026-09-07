class Lesson {
  static const prototypeSantaliMarker = '[Prototype Santali Translation]';

  final int? id;
  final String grade;
  final String subject;
  final String topic;
  final String learningOutcome;
  final String hindiInstruction;
  final String? santaliTranslation;
  final bool isPrototypeTranslation;

  Lesson({
    this.id,
    required this.grade,
    required this.subject,
    required this.topic,
    required this.learningOutcome,
    required this.hindiInstruction,
    this.santaliTranslation,
    this.isPrototypeTranslation = false,
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
    );
  }
}
