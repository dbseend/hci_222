class ApiEndpoints {
  static const String baseUrl = String.fromEnvironment(
    'TRUEPRICE_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String detectObject = '/scan/detect-object';
  static const String priceCompare = '/api/v1/price/compare';
  static const String submitPrice = '/prices/submit';
  static const String marketsNearby = '/markets/nearby';
  static const String phrases = '/phrases';
  static const String communityFeed = '/api/v1/community/feed';
  static const String communityPosts = '/api/v1/community/posts';
  static const String scanHistory = '/scan/history';

  static String productPriceStats(String productId) =>
      '/api/v1/products/$productId/price-stats';
}
