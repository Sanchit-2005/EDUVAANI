/// A teacher-authored assignment saved locally for reuse.
///
/// Custom assignments are composed on [CustomAssignmentScreen], persisted via
/// [DatabaseHelper], and rendered into PDFs through the same
/// [WorksheetService.buildCustomWorksheet] engine used by auto-generated
/// worksheets — there is never a second rendering path.
class CustomAssignment {
  const CustomAssignment({
    this.id,
    required this.grade,
    required this.subject,
    required this.topic,
    required this.questionsJson,
    this.includeHindi = true,
    this.includeSantali = true,
    this.includeEnglish = false,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String grade;
  final String subject;
  final String topic;

  /// JSON-encoded list of question objects. Stored as text so the schema stays
  /// flat and question count can vary freely.
  final String questionsJson;

  final bool includeHindi;
  final bool includeSantali;
  final bool includeEnglish;
  final String createdAt;
  final String? updatedAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'grade': grade,
        'subject': subject,
        'topic': topic,
        'questions_json': questionsJson,
        'include_hindi': includeHindi ? 1 : 0,
        'include_santali': includeSantali ? 1 : 0,
        'include_english': includeEnglish ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory CustomAssignment.fromMap(Map<String, Object?> map) =>
      CustomAssignment(
        id: map['id'] as int?,
        grade: map['grade'] as String,
        subject: map['subject'] as String,
        topic: map['topic'] as String,
        questionsJson: map['questions_json'] as String,
        includeHindi: (map['include_hindi'] as int) == 1,
        includeSantali: (map['include_santali'] as int) == 1,
        includeEnglish: (map['include_english'] as int) == 1,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String?,
      );
}
