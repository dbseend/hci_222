class ScanRouteData {
  final String productName;
  final String productId;
  final double? detectedPrice;
  final double inputPrice;
  final double finalPrice;
  final String? capturedImagePath;

  const ScanRouteData({
    this.productName = '',
    this.productId = 'tomato',
    this.detectedPrice,
    this.inputPrice = 0,
    this.finalPrice = 0,
    this.capturedImagePath,
  });

  factory ScanRouteData.fromExtra(Object? extra) {
    if (extra is ScanRouteData) return extra;
    if (extra is Map<String, dynamic>) {
      return ScanRouteData(
        productName: extra['productName'] as String? ?? '',
        productId: extra['productId'] as String? ?? 'tomato',
        detectedPrice: (extra['detectedPrice'] as num?)?.toDouble(),
        inputPrice: (extra['inputPrice'] as num?)?.toDouble() ?? 0,
        finalPrice: (extra['finalPrice'] as num?)?.toDouble() ?? 0,
        capturedImagePath: extra['capturedImagePath'] as String?,
      );
    }
    return const ScanRouteData();
  }
}
