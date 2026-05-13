import 'detection_result.dart';

class ScanHistoryItem {
  final String id;
  final String imagePath;
  final String? remoteImagePath;
  final String? imageUrl;
  final DateTime capturedAt;
  final DetectionResult? detectionResult;
  final double? quotedTotalPriceEgp;
  final double? quotedQuantity;
  final String? quotedUnit;
  final double? quotedUnitPriceEgp;

  const ScanHistoryItem({
    required this.id,
    required this.imagePath,
    this.remoteImagePath,
    this.imageUrl,
    required this.capturedAt,
    this.detectionResult,
    this.quotedTotalPriceEgp,
    this.quotedQuantity,
    this.quotedUnit,
    this.quotedUnitPriceEgp,
  });

  bool get canDisplay =>
      imagePath.isNotEmpty || (imageUrl?.isNotEmpty ?? false);
  bool get hasDetectionCache => detectionResult != null;
  bool get hasQuotedPrice =>
      quotedUnitPriceEgp != null && quotedUnitPriceEgp! > 0;

  ScanHistoryItem copyWith({
    String? id,
    String? imagePath,
    String? remoteImagePath,
    String? imageUrl,
    DateTime? capturedAt,
    DetectionResult? detectionResult,
    double? quotedTotalPriceEgp,
    double? quotedQuantity,
    String? quotedUnit,
    double? quotedUnitPriceEgp,
  }) {
    return ScanHistoryItem(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      remoteImagePath: remoteImagePath ?? this.remoteImagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      capturedAt: capturedAt ?? this.capturedAt,
      detectionResult: detectionResult ?? this.detectionResult,
      quotedTotalPriceEgp: quotedTotalPriceEgp ?? this.quotedTotalPriceEgp,
      quotedQuantity: quotedQuantity ?? this.quotedQuantity,
      quotedUnit: quotedUnit ?? this.quotedUnit,
      quotedUnitPriceEgp: quotedUnitPriceEgp ?? this.quotedUnitPriceEgp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_path': imagePath,
    'remote_image_path': remoteImagePath,
    'image_url': imageUrl,
    'captured_at': capturedAt.toIso8601String(),
    'detection_result': detectionResult?.toJson(),
    'quoted_total_price_egp': quotedTotalPriceEgp,
    'quoted_quantity': quotedQuantity,
    'quoted_unit': quotedUnit,
    'quoted_unit_price_egp': quotedUnitPriceEgp,
  };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    final detectionJson = json['detection_result'];
    return ScanHistoryItem(
      id: json['id'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      remoteImagePath: json['remote_image_path'] as String?,
      imageUrl: json['image_url'] as String?,
      capturedAt:
          DateTime.tryParse(json['captured_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      detectionResult: detectionJson is Map<String, dynamic>
          ? DetectionResult.fromJson(detectionJson)
          : null,
      quotedTotalPriceEgp: (json['quoted_total_price_egp'] as num?)?.toDouble(),
      quotedQuantity: (json['quoted_quantity'] as num?)?.toDouble(),
      quotedUnit: json['quoted_unit'] as String?,
      quotedUnitPriceEgp: (json['quoted_unit_price_egp'] as num?)?.toDouble(),
    );
  }

  factory ScanHistoryItem.fromApiJson(Map<String, dynamic> json) {
    final productCode = json['detected_product_code'] as String?;
    final productName = json['detected_product_name'] as String?;
    final confidence = (json['detection_confidence'] as num?)?.toDouble();
    return ScanHistoryItem(
      id: json['id'] as String? ?? '',
      imagePath: '',
      remoteImagePath: json['image_path'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      capturedAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      detectionResult:
          productCode != null &&
              productCode.isNotEmpty &&
              productName != null &&
              productName.isNotEmpty &&
              confidence != null
          ? DetectionResult(
              productId: productCode,
              productName: productName,
              productNameAr: json['detected_product_name_ar'] as String? ?? '',
              confidence: confidence,
              detectedPrice: (json['detected_price_egp'] as num?)?.toDouble(),
            )
          : null,
      quotedTotalPriceEgp: (json['quoted_total_price_egp'] as num?)?.toDouble(),
      quotedQuantity: (json['quoted_quantity'] as num?)?.toDouble(),
      quotedUnit: json['quoted_unit'] as String?,
      quotedUnitPriceEgp: (json['quoted_unit_price_egp'] as num?)?.toDouble(),
    );
  }
}
