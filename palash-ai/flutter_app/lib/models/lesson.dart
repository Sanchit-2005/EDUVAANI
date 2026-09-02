class Lesson {
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

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'grade': grade,
      'subject': subject,
      'topic': topic,
      'learningOutcome': learningOutcome,
      'hindiInstruction': hindiInstruction,
      'santaliTranslation': santaliTranslation,
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
      santaliTranslation: map['santaliTranslation'],
      isPrototypeTranslation: map['isPrototypeTranslation'] == 1,
    );
  }
}
