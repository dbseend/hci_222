import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    return _instance!;
  }
}
