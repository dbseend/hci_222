import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';

class DioClient {
  static Dio? _instance;
  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 45);

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
