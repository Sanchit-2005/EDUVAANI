class SyncStatus {
  const SyncStatus({
    required this.lastSyncedAt,
    required this.downloadedLessons,
    required this.downloadedTranslations,
    required this.downloadedModels,
  });

  final DateTime? lastSyncedAt;
  final int downloadedLessons;
  final int downloadedTranslations;
  final int downloadedModels;

  Map<String, Object?> toMap() => {
    'id': 1,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'downloadedLessons': downloadedLessons,
    'downloadedTranslations': downloadedTranslations,
    'downloadedModels': downloadedModels,
  };

  factory SyncStatus.fromMap(Map<String, Object?> map) => SyncStatus(
    lastSyncedAt: map['lastSyncedAt'] == null ? null : DateTime.parse(map['lastSyncedAt'] as String),
    downloadedLessons: map['downloadedLessons'] as int,
    downloadedTranslations: map['downloadedTranslations'] as int,
    downloadedModels: map['downloadedModels'] as int,
  );

  static const empty = SyncStatus(
    lastSyncedAt: null,
    downloadedLessons: 0,
    downloadedTranslations: 0,
    downloadedModels: 0,
  );
}
