// region_stats.dart
// Purpose: Models for the regional price statistics fetched from the backend
//          (or served from mock data during development).
//          PriceBucket represents one bar in the histogram.
//          RegionStats holds the full distribution for a product in a given region.
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
  final String region;
  final String currency;
  final double avgPrice;
  final double modePrice;
  final double maxPrice;
  final double minPrice;
  final double stdDev;
  final int sampleCount;
  final List<PriceBucket> distribution;

  const RegionStats({
    required this.productId,
    this.region = 'cairo',
    this.currency = 'EGP',
    required this.avgPrice,
    required this.modePrice,
    required this.maxPrice,
    required this.minPrice,
    required this.stdDev,
    required this.sampleCount,
    required this.distribution,
  });

  factory RegionStats.fromJson(Map<String, dynamic> json) {
    final avgPrice = (json['avg_price'] as num).toDouble();
    final minPrice = (json['min_price'] as num).toDouble();
    final maxPrice = (json['max_price'] as num).toDouble();
    final sampleCount = (json['sample_count'] as num?)?.toInt() ?? 0;
    final distributionJson = json['distribution'];

    return RegionStats(
      productId: json['product_id'] as String,
      region: json['region'] as String? ?? 'cairo',
      currency: json['currency'] as String? ?? 'EGP',
      avgPrice: avgPrice,
      modePrice:
          ((json['mode_price'] ?? json['median_price'] ?? avgPrice) as num)
              .toDouble(),
      maxPrice: maxPrice,
      minPrice: minPrice,
      stdDev: ((json['std_dev'] ?? json['stddev_price'] ?? 0) as num)
          .toDouble(),
      sampleCount: sampleCount,
      distribution: distributionJson is List
          ? distributionJson
                .map((e) => PriceBucket.fromJson(e as Map<String, dynamic>))
                .toList()
          : _buildSyntheticDistribution(
              minPrice: minPrice,
              maxPrice: maxPrice,
              avgPrice: avgPrice,
              sampleCount: sampleCount,
            ),
    );
  }

  // Mock data for MVP. Units are product-specific:
  // - p001: EGP/kg for grapes
  // TODO(next-dev): Replace with RegionStats.fromJson() once the backend is connected
  static RegionStats mock(String productId) {
    return RegionStats(
      productId: productId,
      sampleCount: 88,
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

  static List<PriceBucket> _buildSyntheticDistribution({
    required double minPrice,
    required double maxPrice,
    required double avgPrice,
    required int sampleCount,
  }) {
    if (sampleCount <= 0 || maxPrice <= minPrice) return const [];

    const bucketCount = 8;
    final width = (maxPrice - minPrice) / bucketCount;
    final weights = List<double>.generate(bucketCount, (index) {
      final center = minPrice + width * (index + 0.5);
      final distance = ((center - avgPrice).abs() / (maxPrice - minPrice))
          .clamp(0.0, 1.0);
      return 1.0 - distance;
    });
    final totalWeight = weights.fold<double>(0, (sum, value) => sum + value);

    var assigned = 0;
    final buckets = <PriceBucket>[];
    for (var i = 0; i < bucketCount; i++) {
      final isLast = i == bucketCount - 1;
      final count = isLast
          ? sampleCount - assigned
          : (sampleCount * weights[i] / totalWeight).round();
      assigned += count;
      buckets.add(
        PriceBucket(
          start: minPrice + width * i,
          end: minPrice + width * (i + 1),
          count: count,
        ),
      );
    }
    return buckets;
  }
}
