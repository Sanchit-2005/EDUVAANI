class ProgressRecord {
  const ProgressRecord({
    this.id,
    required this.className,
    required this.students,
    required this.lessonsCompleted,
    required this.totalLessons,
    required this.literacyPercent,
    required this.numeracyPercent,
    required this.vocabularyPercent,
  });

  final int? id;
  final String className;
  final int students;
  final int lessonsCompleted;
  final int totalLessons;
  final int literacyPercent;
  final int numeracyPercent;
  final int vocabularyPercent;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'className': className,
    'students': students,
    'lessonsCompleted': lessonsCompleted,
    'totalLessons': totalLessons,
    'literacyPercent': literacyPercent,
    'numeracyPercent': numeracyPercent,
    'vocabularyPercent': vocabularyPercent,
  };

  factory ProgressRecord.fromMap(Map<String, Object?> map) => ProgressRecord(
    id: map['id'] as int?,
    className: map['className'] as String,
    students: map['students'] as int,
    lessonsCompleted: map['lessonsCompleted'] as int,
    totalLessons: map['totalLessons'] as int,
    literacyPercent: map['literacyPercent'] as int,
    numeracyPercent: map['numeracyPercent'] as int,
    vocabularyPercent: map['vocabularyPercent'] as int,
  );
}
