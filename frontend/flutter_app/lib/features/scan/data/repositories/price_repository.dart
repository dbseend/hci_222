import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/constants/api_endpoints.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../../../core/utils/price_classifier.dart';
import '../models/price_comparison.dart';
import '../models/region_stats.dart';

abstract class PriceRepository {
  Future<RegionStats> getStats({
    required String productId,
    required double lat,
    required double lon,
  });

  Future<PriceComparison> comparePrice({
    required String productId,
    required double price,
    String region = 'cairo',
    String currency = 'EGP',
  });

  Future<void> submitPrice({
    required String productId,
    required double price,
    required String unit,
    required double lat,
    required double lon,
    required String userId,
  });
}

class PriceRepositoryImpl implements PriceRepository {
  final Dio _dio;

  PriceRepositoryImpl({Dio? dio}) : _dio = dio ?? DioClient.instance;

  static final Map<String, RegionStats> _cache = {};

  @override
  Future<RegionStats> getStats({
    required String productId,
    required double lat,
    required double lon,
  }) async {
    const region = 'cairo';
    final cacheKey = '$productId:$region';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.productPriceStats(productId),
        queryParameters: {'region': region},
      );
      final stats = RegionStats.fromJson(res.data!);
      _cache[cacheKey] = stats;
      return stats;
    } on DioException catch (e) {
      debugPrint(
        '[PriceRepository] Failed to load price stats from API: $e. '
        'Using local MVP fallback.',
      );
      final stats = RegionStats.mock(productId);
      _cache[cacheKey] = stats;
      return stats;
    }
  }

  @override
  Future<PriceComparison> comparePrice({
    required String productId,
    required double price,
    String region = 'cairo',
    String currency = 'EGP',
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.priceCompare,
        data: {
          'product_id': productId,
          'region': region,
          'user_price': price,
          'currency': currency,
        },
      );
      return PriceComparison.fromJson(res.data!);
    } on DioException catch (e) {
      debugPrint(
        '[PriceRepository] Failed to compare price from API: $e. '
        'Using local MVP fallback.',
      );
      return _localComparison(
        productId: productId,
        price: price,
        region: region,
        currency: currency,
      );
    }
  }

  @override
  Future<void> submitPrice({
    required String productId,
    required double price,
    required String unit,
    required double lat,
    required double lon,
    required String userId,
  }) async {
    _cache.removeWhere((key, _) => key.startsWith('$productId:'));
  }

  /// Clears the in-memory cache — useful in tests to force a fresh fetch.
  static void clearCache() => _cache.clear();

  PriceComparison _localComparison({
    required String productId,
    required double price,
    required String region,
    required String currency,
  }) {
    final cacheKey = '$productId:$region';
    final stats = _cache[cacheKey] ?? RegionStats.mock(productId);
    final sampleCount = stats.sampleCount > 0
        ? stats.sampleCount
        : stats.distribution.fold<int>(0, (sum, bucket) => sum + bucket.count);
    final percentDiff = PriceClassifier.percentDiff(price, stats.avgPrice);
    final status = PriceClassifier.classify(
      observed: price,
      avg: stats.avgPrice,
      stdDev: stats.stdDev,
    );
    final verdict = switch (status) {
      PriceStatus.safe => 'fair',
      PriceStatus.negotiable => 'negotiable',
      PriceStatus.warning => 'overpriced',
    };

    return PriceComparison(
      productId: productId,
      displayName: productId,
      unit: 'kg',
      region: stats.region,
      currency: stats.currency,
      userPrice: price,
      avgPrice: stats.avgPrice,
      medianPrice: stats.modePrice,
      minPrice: stats.minPrice,
      maxPrice: stats.maxPrice,
      stdDev: stats.stdDev,
      sampleCount: sampleCount,
      percentDiff: percentDiff,
      verdict: verdict,
      message:
          '${PriceClassifier.statusMessage(status, percentDiff)} '
          '${PriceClassifier.priceDeltaLabel(percentDiff)}.',
    );
  }
}
