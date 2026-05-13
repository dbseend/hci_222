// detection_result.dart
// Purpose: Model that carries the output of the product-detection step (camera → AI).
//          Contains the recognized product identity, Arabic name, confidence score,
//          and a nullable price field kept only for API compatibility.
// Web-only mock still uses DetectionResult.mock(); mobile calls the backend
// /scan/detect-object endpoint, which currently returns backend mock detections.
// TODO(next-dev): Add 'unit' field (kg / pcs / bunch) from the API response
//                 so PriceInputScreen can pre-select the correct unit chip.

class DetectionResult {
  final String productId;
  final String productName;
  final String productNameAr;
  final double confidence;
  final double? detectedPrice;

  const DetectionResult({
    required this.productId,
    required this.productName,
    required this.productNameAr,
    required this.confidence,
    this.detectedPrice,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      productId: json['product_id'] as String,
      productName: json['name_kr'] as String,
      productNameAr: json['name_ar'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      detectedPrice: json['detected_price'] != null
          ? (json['detected_price'] as num).toDouble()
          : null,
    );
  }

  // Web fallback result when File upload is unavailable.
  static DetectionResult mock() => const DetectionResult(
    productId: 'fruit',
    productName: 'Fruit',
    productNameAr: 'فاكهة',
    confidence: 0.92,
    detectedPrice: 25.0,
  );
}
