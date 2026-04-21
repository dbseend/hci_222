// region_stats.dart
// Purpose: Models for the regional price statistics fetched from the backend
//          (or served from mock data during development).
//          PriceBucket represents one bar in the histogram.
//          RegionStats holds the full distribution for a product in a given region.
// Mock→Real migration: replace RegionStats.mock() with RegionStats.fromJson(res.data)
//                      once the price-stats API endpoint is live.
// TODO(next-dev): Add 'currency' and 'unit' fields to RegionStats so the UI can
//                 display "EGP / kg" instead of hard-coding the unit label.

class PriceBucket {
  final double start;
  final double end;
  final int count;

  const PriceBucket({
    required this.start,
    required this.end,
    required this.count,
  });

  factory PriceBucket.fromJson(Map<String, dynamic> json) => PriceBucket(
        start: (json['bucket_start'] as num).toDouble(),
        end: (json['bucket_end'] as num).toDouble(),
        count: json['count'] as int,
      );
}

class RegionStats {
  final String productId;
  final double avgPrice;
  final double modePrice;
  final double maxPrice;
  final double minPrice;
  final double stdDev;
  final List<PriceBucket> distribution;

  const RegionStats({
    required this.productId,
    required this.avgPrice,
    required this.modePrice,
    required this.maxPrice,
    required this.minPrice,
    required this.stdDev,
    required this.distribution,
  });

  factory RegionStats.fromJson(Map<String, dynamic> json) => RegionStats(
        productId: json['product_id'] as String,
        avgPrice: (json['avg_price'] as num).toDouble(),
        modePrice: (json['mode_price'] as num).toDouble(),
        maxPrice: (json['max_price'] as num).toDouble(),
        minPrice: (json['min_price'] as num).toDouble(),
        stdDev: (json['std_dev'] as num).toDouble(),
        distribution: (json['distribution'] as List)
            .map((e) => PriceBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  // Mock data: Grapes 1 kg, Khan el-Khalili Market, Cairo (unit: EGP)
  // Reference values from project proposal: grapes 40–80 EGP, average 55 EGP
  // TODO(next-dev): Replace with RegionStats.fromJson() once the backend is connected
  static RegionStats mock(String productId) => RegionStats(
        productId: productId,
        avgPrice: 55.0,
        modePrice: 50.0,
        maxPrice: 80.0,
        minPrice: 40.0,
        stdDev: 10.0,
        distribution: const [
          PriceBucket(start: 40, end: 45, count: 4),
          PriceBucket(start: 45, end: 50, count: 10),
          PriceBucket(start: 50, end: 55, count: 20),
          PriceBucket(start: 55, end: 60, count: 24),
          PriceBucket(start: 60, end: 65, count: 16),
          PriceBucket(start: 65, end: 70, count: 8),
          PriceBucket(start: 70, end: 75, count: 4),
          PriceBucket(start: 75, end: 80, count: 2),
        ],
      );
}
