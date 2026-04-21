// price_repository.dart
// Purpose: Repository interface + mock implementation for price data.
//          PriceRepository defines the two operations the app needs:
//            1. getStats()    — fetch regional price distribution for a product
//            2. submitPrice() — crowdsource a new price observation from the user
//          PriceRepositoryImpl currently uses mock data with simulated network delays.
//
// Mock→Real migration path:
//   1. Uncomment the DioClient blocks in getStats() and submitPrice().
//   2. Import DioClient and ApiEndpoints from the network layer.
//   3. Delete the RegionStats.mock() call and Future.delayed stubs.
//   The in-memory cache (_cache) stays in place to reduce redundant API calls.
//
// Architecture: injected into the ScanBloc via the constructor; swap mock for real at DI site.

import '../models/region_stats.dart';

abstract class PriceRepository {
  Future<RegionStats> getStats({
    required String productId,
    required double lat,
    required double lon,
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
  // Simple in-memory cache: each productId is fetched at most once per app session
  static final Map<String, RegionStats> _cache = {};

  @override
  Future<RegionStats> getStats({
    required String productId,
    required double lat,
    required double lon,
  }) async {
    if (_cache.containsKey(productId)) {
      return _cache[productId]!;
    }

    // TODO(next-dev): Uncomment when backend is ready
    // final res = await DioClient.instance.get(
    //   ApiEndpoints.priceStats,
    //   queryParameters: {'product_id': productId, 'lat': lat, 'lon': lon},
    // );
    // final stats = RegionStats.fromJson(res.data);
    // _cache[productId] = stats;
    // return stats;

    await Future.delayed(const Duration(milliseconds: 500));
    final stats = RegionStats.mock(productId);
    _cache[productId] = stats;
    return stats;
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
    // TODO(next-dev): Uncomment when backend is ready
    // await DioClient.instance.post(ApiEndpoints.submitPrice, data: {
    //   'product_id': productId,
    //   'price': price,
    //   'unit': unit,
    //   'lat': lat,
    //   'lon': lon,
    //   'user_id': userId,
    // });

    // Invalidate cache for this product so the next getStats() call returns fresh data
    _cache.remove(productId);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Clears the in-memory cache — useful in tests to force a fresh fetch.
  static void clearCache() => _cache.clear();
}
