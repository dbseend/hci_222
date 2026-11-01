import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trueprice/core/network/dio_client.dart';
import 'package:trueprice/core/services/auth_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('creates and persists a Supabase anonymous session', () async {
    final adapter = _AnonymousSignInAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final prefs = await SharedPreferences.getInstance();
    final service = AuthSessionService(
      dio: dio,
      prefsProvider: () async => prefs,
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'publishable-key',
    );

    expect(await service.getAccessToken(), 'access-token');
    expect(await service.getUserId(), '11111111-1111-4111-8111-111111111111');
    expect(adapter.signInCalls, 1);

    final restored = AuthSessionService(
      dio: Dio()..httpClientAdapter = _FailingAdapter(),
      prefsProvider: () async => prefs,
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'publishable-key',
    );

    expect(await restored.getAccessToken(), 'access-token');
  });

  test('refreshes an expired Supabase session', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    SharedPreferences.setMockInitialValues({
      'supabase_access_token': 'expired-token',
      'supabase_refresh_token': 'refresh-token',
      'supabase_access_token_expires_at': now - 10,
      'supabase_user_id': '11111111-1111-4111-8111-111111111111',
    });
    final prefs = await SharedPreferences.getInstance();
    final adapter = _RefreshAdapter();
    final service = AuthSessionService(
      dio: Dio()..httpClientAdapter = adapter,
      prefsProvider: () async => prefs,
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'publishable-key',
    );

    expect(await service.getAccessToken(), 'refreshed-access-token');
    expect(adapter.refreshCalls, 1);
  });

  test('adds the verified bearer token to backend requests', () async {
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthSessionService(
      dio: Dio()..httpClientAdapter = _AnonymousSignInAdapter(),
      prefsProvider: () async => prefs,
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'publishable-key',
    );
    final backendAdapter = _BackendAuthorizationAdapter();
    final backendDio = Dio()
      ..httpClientAdapter = backendAdapter
      ..interceptors.add(BackendAuthInterceptor(authSession: auth));

    await backendDio.get<void>('https://api.example.test/scan/history');

    expect(backendAdapter.authorization, 'Bearer access-token');
  });
}

class _AnonymousSignInAdapter implements HttpClientAdapter {
  int signInCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.method, 'POST');
    expect(options.path, 'https://project.supabase.co/auth/v1/signup');
    expect(options.headers['apikey'], 'publishable-key');
    signInCalls += 1;
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'access-token',
        'refresh_token': 'refresh-token',
        'expires_in': 3600,
        'user': {'id': '11111111-1111-4111-8111-111111111111'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RefreshAdapter implements HttpClientAdapter {
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.method, 'POST');
    expect(
      options.uri.toString(),
      'https://project.supabase.co/auth/v1/token?grant_type=refresh_token',
    );
    expect(options.headers['apikey'], 'publishable-key');
    refreshCalls += 1;
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'refreshed-access-token',
        'refresh_token': 'rotated-refresh-token',
        'expires_in': 3600,
        'user': {'id': '11111111-1111-4111-8111-111111111111'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw StateError('A persisted valid session must not hit the network.');
  }

  @override
  void close({bool force = false}) {}
}

class _BackendAuthorizationAdapter implements HttpClientAdapter {
  String? authorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorization = options.headers['Authorization'] as String?;
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}
