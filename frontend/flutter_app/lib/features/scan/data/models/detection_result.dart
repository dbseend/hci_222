// detection_result.dart
// Purpose: Model that carries the output of the product-detection step (camera → AI).
//          Contains the recognized product identity, Arabic name, confidence score,
//          and optionally a price read from the price tag in the camera frame.
// Mock→Real migration: replace DetectionResult.mock() with DetectionResult.fromJson(res.data)
//                      once the YOLO/detection backend endpoint is available.
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

  // Mock result: Grapes, price in EGP (Cairo baseline)
  // TODO(next-dev): Replace with DetectionResult.fromJson(res.data) once the YOLO backend is wired up
  static DetectionResult mock() => const DetectionResult(
        productId: 'p001',
        productName: 'Tomate',
        productNameAr: 'عنب',
        confidence: 0.92,
        detectedPrice: 65.0,
      );
}
