import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trueprice/features/community/data/repositories/community_post_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityPostRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds purchase post and returns newest first', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = CommunityPostRepositoryImpl(
        prefsProvider: () async => prefs,
        dio: _dioThatCannotConnect(),
        allowDemoFallbacks: true,
      );

      await repo.addPurchasePost(
        productName: 'Grapes',
        price: 61,
        imagePath: '/tmp/grapes.jpg',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.addPurchasePost(
        productName: 'Tomato',
        price: 14,
        imagePath: '/tmp/tomato.jpg',
      );

      final posts = await repo.getUserPosts();
      expect(posts.length, 2);
      expect(posts.first.productName, 'Tomato');
      expect(posts.first.price, 14);
      expect(posts.first.imagePath, '/tmp/tomato.jpg');
      expect(posts.first.createdAt.isAfter(posts.last.createdAt), isTrue);
    });

    test('returns sample feed when no community posts exist yet', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = CommunityPostRepositoryImpl(
        prefsProvider: () async => prefs,
        dio: _dioThatCannotConnect(),
        allowDemoFallbacks: true,
      );

      final posts = await repo.getUserPosts();

      expect(posts, isNotEmpty);
      expect(posts.map((post) => post.productName), contains('Tomatoes 1kg'));
      expect(posts.map((post) => post.storeName), contains('Ataba Market'));
    });

    test('propagates write failure when demo fallbacks are disabled', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = CommunityPostRepositoryImpl(
        prefsProvider: () async => prefs,
        dio: _dioThatCannotConnect(),
        allowDemoFallbacks: false,
      );

      expect(
        () => repo.addPurchasePost(productName: 'Tomato', price: 14),
        throwsA(isA<DioException>()),
      );
    });

    test(
      'keeps an empty remote feed empty when demo fallbacks are disabled',
      () async {
        final repo = CommunityPostRepositoryImpl(
          dio: _dioReturningEmptyFeed(),
          allowDemoFallbacks: false,
        );

        final posts = await repo.getUserPosts();

        expect(posts, isEmpty);
      },
    );
  });
}

Dio _dioThatCannotConnect() {
  return Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'))
    ..httpClientAdapter = _ConnectionErrorAdapter();
}

Dio _dioReturningEmptyFeed() {
  return Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..httpClientAdapter = _EmptyFeedAdapter();
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

class _EmptyFeedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
