import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/features/scan/data/repositories/price_repository.dart';

void main() {
  group('PriceRepositoryImpl offline fallback', () {
    setUp(PriceRepositoryImpl.clearCache);

    test('returns mock stats when the price API is unreachable', () async {
      final repo = PriceRepositoryImpl(dio: _dioThatCannotConnect());

      final stats = await repo.getStats(productId: 'tomato', lat: 0, lon: 0);

      expect(stats.productId, 'tomato');
      expect(stats.avgPrice, 18.4);
      expect(stats.distribution, isNotEmpty);
    });

    test(
      'returns local comparison when the compare API is unreachable',
      () async {
        final repo = PriceRepositoryImpl(dio: _dioThatCannotConnect());

        final comparison = await repo.comparePrice(
          productId: 'tomato',
          price: 65,
        );

        expect(comparison.productId, 'tomato');
        expect(comparison.userPrice, 65);
        expect(comparison.avgPrice, 18.4);
        expect(comparison.verdict, 'overpriced');
        expect(comparison.message, contains('Cairo reference'));
      },
    );
  });
}

Dio _dioThatCannotConnect() {
  return Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'))
    ..httpClientAdapter = _ConnectionErrorAdapter();
}

class _ConnectionErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Connection refused',
    );
  }

  @override
  void close({bool force = false}) {}
}
