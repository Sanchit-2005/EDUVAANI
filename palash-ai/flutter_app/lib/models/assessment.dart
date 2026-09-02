class AssessmentQuestion {
  const AssessmentQuestion({
    this.id,
    required this.grade,
    required this.subject,
    required this.topic,
    required this.questionNumber,
    required this.hindiText,
    required this.santaliText,
  });

  final int? id;
  final String grade;
  final String subject;
  final String topic;
  final int questionNumber;
  final String hindiText;
  final String santaliText;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'grade': grade,
    'subject': subject,
    'topic': topic,
    'questionNumber': questionNumber,
    'hindiText': hindiText,
    'santaliText': santaliText,
  };

  factory AssessmentQuestion.fromMap(Map<String, Object?> map) => AssessmentQuestion(
    id: map['id'] as int?,
    grade: map['grade'] as String,
    subject: map['subject'] as String,
    topic: map['topic'] as String,
    questionNumber: map['questionNumber'] as int,
    hindiText: map['hindiText'] as String,
    santaliText: map['santaliText'] as String,
  );
}
