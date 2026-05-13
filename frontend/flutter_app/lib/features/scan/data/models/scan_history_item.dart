class ScanHistoryItem {
  final String id;
  final String imagePath;
  final String? remoteImagePath;
  final String? imageUrl;
  final DateTime capturedAt;

  const ScanHistoryItem({
    required this.id,
    required this.imagePath,
    this.remoteImagePath,
    this.imageUrl,
    required this.capturedAt,
  });

  bool get canDisplay =>
      imagePath.isNotEmpty || (imageUrl?.isNotEmpty ?? false);

  ScanHistoryItem copyWith({
    String? id,
    String? imagePath,
    String? remoteImagePath,
    String? imageUrl,
    DateTime? capturedAt,
  }) {
    return ScanHistoryItem(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      remoteImagePath: remoteImagePath ?? this.remoteImagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_path': imagePath,
    'remote_image_path': remoteImagePath,
    'image_url': imageUrl,
    'captured_at': capturedAt.toIso8601String(),
  };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: json['id'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      remoteImagePath: json['remote_image_path'] as String?,
      imageUrl: json['image_url'] as String?,
      capturedAt:
          DateTime.tryParse(json['captured_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory ScanHistoryItem.fromApiJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: json['id'] as String? ?? '',
      imagePath: '',
      remoteImagePath: json['image_path'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      capturedAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
