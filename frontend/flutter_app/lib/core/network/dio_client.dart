import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';

class DioClient {
  static Dio? _instance;
  static Duration get _connectTimeout =>
      kIsWeb ? const Duration(seconds: 12) : const Duration(seconds: 30);
  static Duration get _receiveTimeout =>
      kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 45);

  static Dio get instance {
    _instance ??= Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
      ),
    );
    return _instance!;
  }

  static void setInstanceForTest(Dio dio) {
    _instance = dio;
  }

  static void resetForTest() {
    _instance = null;
  }
}
