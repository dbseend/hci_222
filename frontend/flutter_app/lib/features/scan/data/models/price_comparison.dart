class PriceComparison {
  final String productId;
  final String displayName;
  final String unit;
  final String region;
  final String currency;
  final double userPrice;
  final double avgPrice;
  final double medianPrice;
  final double minPrice;
  final double maxPrice;
  final double stdDev;
  final int sampleCount;
  final double percentDiff;
  final String verdict;
  final String message;

  const PriceComparison({
    required this.productId,
    required this.displayName,
    required this.unit,
    required this.region,
    required this.currency,
    required this.userPrice,
    required this.avgPrice,
    required this.medianPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.stdDev,
    required this.sampleCount,
    required this.percentDiff,
    required this.verdict,
    required this.message,
  });

  factory PriceComparison.fromJson(Map<String, dynamic> json) {
    return PriceComparison(
      productId: json['product_id'] as String,
      displayName: json['display_name'] as String,
      unit: json['unit'] as String,
      region: json['region'] as String,
      currency: json['currency'] as String,
      userPrice: (json['user_price'] as num).toDouble(),
      avgPrice: (json['avg_price'] as num).toDouble(),
      medianPrice: (json['median_price'] as num).toDouble(),
      minPrice: (json['min_price'] as num).toDouble(),
      maxPrice: (json['max_price'] as num).toDouble(),
      stdDev: (json['stddev_price'] as num).toDouble(),
      sampleCount: (json['sample_count'] as num).toInt(),
      percentDiff: (json['percent_diff'] as num).toDouble(),
      verdict: json['verdict'] as String,
      message: json['message'] as String,
    );
  }
}
