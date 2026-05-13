import 'generated_env.dart';

class ApiEndpoints {
  static const String baseUrl = GeneratedEnv.truepriceApiBaseUrl;

  static const String detectObject = '/scan/detect-object';
  static const String priceCompare = '/api/v1/price/compare';
  static const String submitPrice = '/prices/submit';
  static const String marketsNearby = '/markets/nearby';
  static const String phrases = '/phrases';
  static const String communityFeed = '/api/v1/community/feed';
  static const String communityPosts = '/api/v1/community/posts';
  static const String scanHistory = '/scan/history';
  static String scanHistoryDetection(String historyId) =>
      '/scan/history/$historyId/detection';
  static String scanHistoryPrice(String historyId) =>
      '/scan/history/$historyId/price';

  static String productPriceStats(String productId) =>
      '/api/v1/products/$productId/price-stats';
}
