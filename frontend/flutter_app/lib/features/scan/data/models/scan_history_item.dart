class ScanHistoryItem {
  final String id;
  final String imagePath;
  final DateTime capturedAt;

  const ScanHistoryItem({
    required this.id,
    required this.imagePath,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_path': imagePath,
    'captured_at': capturedAt.toIso8601String(),
  };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: json['id'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      capturedAt:
          DateTime.tryParse(json['captured_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
