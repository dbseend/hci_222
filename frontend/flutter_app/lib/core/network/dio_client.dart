import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../services/auth_session_service.dart';

class DioClient {
  static Dio? _instance;
  static Duration get _connectTimeout =>
      kIsWeb ? const Duration(seconds: 12) : const Duration(seconds: 30);
  static Duration get _sendTimeout =>
      kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 45);
  static Duration get _receiveTimeout =>
      kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 90);

  static Dio get instance {
    _instance ??=
        Dio(
            BaseOptions(
              baseUrl: ApiEndpoints.baseUrl,
              connectTimeout: _connectTimeout,
              sendTimeout: _sendTimeout,
              receiveTimeout: _receiveTimeout,
            ),
          )
          ..interceptors.addAll([
            BackendAuthInterceptor(),
            _TruePriceDebugInterceptor(),
          ]);
    return _instance!;
  }

  static void setInstanceForTest(Dio dio) {
    _instance = dio;
  }

  static void resetForTest() {
    _instance = null;
  }
}

class BackendAuthInterceptor extends QueuedInterceptor {
  final AuthSessionService _auth;

  BackendAuthInterceptor({AuthSessionService? authSession})
    : _auth = authSession ?? AuthSessionService.instance;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_auth.isConfigured) {
      handler.next(options);
      return;
    }

    try {
      options.headers['Authorization'] =
          'Bearer ${await _auth.getAccessToken()}';
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: 'Failed to create or refresh the authenticated session.',
        ),
      );
    }
  }
}

class _TruePriceDebugInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[TruePrice API] ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[TruePrice API] ${err.requestOptions.method} '
        '${err.requestOptions.uri} failed: ${err.message}',
      );
    }
    handler.next(err);
  }
}
