import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trueprice/features/scan/data/repositories/price_repository.dart';

void main() {
  group('PriceRepositoryImpl offline fallback', () {
    setUp(PriceRepositoryImpl.clearCache);

    test('returns mock stats when the price API is unreachable', () async {
      final repo = PriceRepositoryImpl(
        dio: _dioThatCannotConnect(),
        allowDemoFallbacks: true,
      );

      final stats = await repo.getStats(productId: 'tomato', lat: 0, lon: 0);

      expect(stats.productId, 'tomato');
      expect(stats.avgPrice, 18.4);
      expect(stats.distribution, isNotEmpty);
    });

    test(
      'returns local comparison when the compare API is unreachable',
      () async {
        final repo = PriceRepositoryImpl(
          dio: _dioThatCannotConnect(),
          allowDemoFallbacks: true,
        );

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

    test('propagates API failure when demo fallbacks are disabled', () async {
      final repo = PriceRepositoryImpl(
        dio: _dioThatCannotConnect(),
        allowDemoFallbacks: false,
      );

      expect(
        () => repo.getStats(productId: 'tomato', lat: 0, lon: 0),
        throwsA(isA<DioException>()),
      );
    });

    test(
      'uses the configured default region for comparison requests',
      () async {
        final adapter = _ComparisonAdapter();
        final repo = PriceRepositoryImpl(
          dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
            ..httpClientAdapter = adapter,
          allowDemoFallbacks: false,
          defaultRegion: 'alexandria',
        );

        await repo.comparePrice(productId: 'tomato', price: 20);

        expect(adapter.lastRequestData?['region'], 'alexandria');
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

class _ComparisonAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastRequestData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestData = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      '{'
      '"product_id":"tomato",'
      '"display_name":"Tomato",'
      '"unit":"kg",'
      '"region":"alexandria",'
      '"currency":"EGP",'
      '"user_price":20.0,'
      '"avg_price":18.0,'
      '"median_price":18.0,'
      '"min_price":12.0,'
      '"max_price":25.0,'
      '"stddev_price":2.0,'
      '"sample_count":20,'
      '"percent_diff":11.1,'
      '"verdict":"fair",'
      '"message":"Fair price"'
      '}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
