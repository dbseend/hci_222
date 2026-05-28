import 'dart:math' as math;

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

class _FallbackPriceStats {
  final double avgPrice;
  final double medianPrice;
  final double minPrice;
  final double maxPrice;
  final double stdDev;
  final int sampleCount;

  const _FallbackPriceStats({
    required this.avgPrice,
    required this.medianPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.stdDev,
    required this.sampleCount,
  });
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
  final int? windowDays;
  final DateTime? lastUpdated;
  final String dataSource;
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
    this.windowDays,
    this.lastUpdated,
    this.dataSource = 'Cairo reference observations',
    required this.distribution,
  });

  factory RegionStats.fromJson(Map<String, dynamic> json) {
    final avgPrice = (json['avg_price'] as num).toDouble();
    final minPrice = (json['min_price'] as num).toDouble();
    final maxPrice = (json['max_price'] as num).toDouble();
    final medianPrice =
        ((json['mode_price'] ?? json['median_price'] ?? avgPrice) as num)
            .toDouble();
    final stdDev = ((json['std_dev'] ?? json['stddev_price'] ?? 0) as num)
        .toDouble();
    final sampleCount = (json['sample_count'] as num?)?.toInt() ?? 0;
    final statDate = json['stat_date'] as String?;
    final distributionJson = json['distribution'];

    return RegionStats(
      productId: json['product_id'] as String,
      region: json['region'] as String? ?? 'cairo',
      currency: json['currency'] as String? ?? 'EGP',
      avgPrice: avgPrice,
      modePrice: medianPrice,
      maxPrice: maxPrice,
      minPrice: minPrice,
      stdDev: stdDev,
      sampleCount: sampleCount,
      windowDays: (json['window_days'] as num?)?.toInt(),
      lastUpdated: statDate == null ? null : DateTime.tryParse(statDate),
      dataSource:
          (json['data_source'] as String?) ?? 'Cairo reference observations',
      distribution: distributionJson is List
          ? distributionJson
                .map((e) => PriceBucket.fromJson(e as Map<String, dynamic>))
                .toList()
          : _buildSyntheticDistribution(
              minPrice: minPrice,
              maxPrice: maxPrice,
              avgPrice: avgPrice,
              medianPrice: medianPrice,
              stdDev: stdDev,
              sampleCount: sampleCount,
            ),
    );
  }

  // Local fallback for MVP when the backend is unreachable.
  // Keep this aligned with the Cairo reference seed used by the backend.
  static RegionStats mock(String productId) {
    final fallback = _fallbackByProduct[productId] ?? _defaultFallback;
    return RegionStats(
      productId: productId,
      sampleCount: fallback.sampleCount,
      avgPrice: fallback.avgPrice,
      modePrice: fallback.medianPrice,
      maxPrice: fallback.maxPrice,
      minPrice: fallback.minPrice,
      stdDev: fallback.stdDev,
      windowDays: 30,
      dataSource: 'Local Cairo MVP fallback',
      distribution: _buildSyntheticDistribution(
        minPrice: fallback.minPrice,
        maxPrice: fallback.maxPrice,
        avgPrice: fallback.avgPrice,
        medianPrice: fallback.medianPrice,
        stdDev: fallback.stdDev,
        sampleCount: fallback.sampleCount,
      ),
    );
  }

  static const _defaultFallback = _FallbackPriceStats(
    avgPrice: 55.0,
    medianPrice: 50.0,
    minPrice: 40.0,
    maxPrice: 80.0,
    stdDev: 10.0,
    sampleCount: 88,
  );

  static const Map<String, _FallbackPriceStats> _fallbackByProduct = {
    'apple': _FallbackPriceStats(
      avgPrice: 85.2,
      medianPrice: 94.0,
      minPrice: 18.0,
      maxPrice: 165.0,
      stdDev: 37.9,
      sampleCount: 36,
    ),
    'avocado': _FallbackPriceStats(
      avgPrice: 203.3,
      medianPrice: 230.0,
      minPrice: 150.0,
      maxPrice: 230.0,
      stdDev: 37.7,
      sampleCount: 10,
    ),
    'blueberry': _FallbackPriceStats(
      avgPrice: 399.9,
      medianPrice: 399.9,
      minPrice: 350.0,
      maxPrice: 430.0,
      stdDev: 25.0,
      sampleCount: 8,
    ),
    'camel_doll': _FallbackPriceStats(
      avgPrice: 125.0,
      medianPrice: 115.0,
      minPrice: 80.0,
      maxPrice: 180.0,
      stdDev: 34.5,
      sampleCount: 18,
    ),
    'cherry': _FallbackPriceStats(
      avgPrice: 220.0,
      medianPrice: 220.0,
      minPrice: 180.0,
      maxPrice: 260.0,
      stdDev: 32.7,
      sampleCount: 6,
    ),
    'cherry_tomato': _FallbackPriceStats(
      avgPrice: 56.7,
      medianPrice: 55.0,
      minPrice: 45.0,
      maxPrice: 70.0,
      stdDev: 10.3,
      sampleCount: 8,
    ),
    'kiwi': _FallbackPriceStats(
      avgPrice: 172.2,
      medianPrice: 200.0,
      minPrice: 116.7,
      maxPrice: 200.0,
      stdDev: 39.3,
      sampleCount: 8,
    ),
    'mango': _FallbackPriceStats(
      avgPrice: 61.8,
      medianPrice: 41.5,
      minPrice: 23.0,
      maxPrice: 175.0,
      stdDev: 51.5,
      sampleCount: 18,
    ),
    'orange': _FallbackPriceStats(
      avgPrice: 22.5,
      medianPrice: 20.0,
      minPrice: 13.0,
      maxPrice: 35.0,
      stdDev: 7.2,
      sampleCount: 32,
    ),
    'rockmelon': _FallbackPriceStats(
      avgPrice: 21.5,
      medianPrice: 22.5,
      minPrice: 12.0,
      maxPrice: 29.0,
      stdDev: 6.3,
      sampleCount: 16,
    ),
    'strawberry': _FallbackPriceStats(
      avgPrice: 49.5,
      medianPrice: 45.0,
      minPrice: 18.0,
      maxPrice: 90.0,
      stdDev: 27.9,
      sampleCount: 16,
    ),
    'tomato': _FallbackPriceStats(
      avgPrice: 18.4,
      medianPrice: 15.0,
      minPrice: 13.0,
      maxPrice: 30.0,
      stdDev: 6.1,
      sampleCount: 18,
    ),
  };

  static List<PriceBucket> _buildSyntheticDistribution({
    required double minPrice,
    required double maxPrice,
    required double avgPrice,
    required double medianPrice,
    required double stdDev,
    required int sampleCount,
  }) {
    if (sampleCount <= 0 || maxPrice <= minPrice) return const [];

    const bucketCount = 8;
    final width = (maxPrice - minPrice) / bucketCount;
    final range = maxPrice - minPrice;
    final centerPrice = (medianPrice * 0.6 + avgPrice * 0.4).clamp(
      minPrice,
      maxPrice,
    );
    final effectiveStdDev = (stdDev > 0 ? stdDev : range / 4)
        .clamp(range / 10, range / 2)
        .toDouble();

    final weights = List<double>.generate(bucketCount, (index) {
      final center = minPrice + width * (index + 0.5);
      final z = (center - centerPrice) / effectiveStdDev;
      final normalWeight = math.exp(-0.5 * z * z);

      // Keep tails visible so the graph communicates the observed min/max range,
      // while still concentrating most samples near the market center.
      return normalWeight + 0.03;
    });
    final totalWeight = weights.fold<double>(0, (sum, value) => sum + value);

    final exactCounts = weights
        .map((weight) => sampleCount * weight / totalWeight)
        .toList();
    final counts = exactCounts.map((value) => value.floor()).toList();
    var assigned = counts.fold<int>(0, (sum, value) => sum + value);

    final remainderOrder = List<int>.generate(bucketCount, (index) => index)
      ..sort((a, b) {
        final aRemainder = exactCounts[a] - counts[a];
        final bRemainder = exactCounts[b] - counts[b];
        return bRemainder.compareTo(aRemainder);
      });

    for (var i = 0; assigned < sampleCount; i++, assigned++) {
      counts[remainderOrder[i % bucketCount]] += 1;
    }

    return List<PriceBucket>.generate(bucketCount, (index) {
      return PriceBucket(
        start: minPrice + width * index,
        end: minPrice + width * (index + 1),
        count: counts[index],
      );
    });
  }
}
