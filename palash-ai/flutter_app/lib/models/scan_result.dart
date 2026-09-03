/// Represents a single Santali scan result.
class ScanResult {
  const ScanResult({
    this.id,
    required this.imagePath,
    required this.santaliText,
    required this.hindiTranslation,
    this.createdAt,
    this.isSynced = false,
  });

  /// Unique identifier (null before insertion)
  final int? id;

  /// Path to the scanned image file (local storage)
  final String imagePath;

  /// Extracted Santali text from OCR
  final String santaliText;

  /// Hindi translation
  final String hindiTranslation;

  /// Timestamp of scan (ISO 8601 format)
  final String? createdAt;

  /// Whether this entry has been synced to backend
  final bool isSynced;

  /// Convert to database map
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'santali_text': santaliText,
      'hindi_translation': hindiTranslation,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Create from database map
  static ScanResult fromMap(Map<String, dynamic> map) {
    return ScanResult(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      santaliText: map['santali_text'] as String,
      hindiTranslation: map['hindi_translation'] as String,
      createdAt: map['created_at'] as String?,
      isSynced: (map['is_synced'] as int?) != 0,
    );
  }

  /// Create a copy with updates
  ScanResult copyWith({
    int? id,
    String? imagePath,
    String? santaliText,
    String? hindiTranslation,
    String? createdAt,
    bool? isSynced,
  }) {
    return ScanResult(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      santaliText: santaliText ?? this.santaliText,
      hindiTranslation: hindiTranslation ?? this.hindiTranslation,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
