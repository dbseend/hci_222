import 'package:dio/dio.dart';

import '../utils/currency_display.dart';

class ExchangeRateService {
  static const _endpoint = 'https://api.frankfurter.dev/v1/latest';
  static bool _didLoadAtAppLaunch = false;

  final Dio _dio;

  ExchangeRateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
            ),
          );

  /// Loads EGP→KRW once at app launch.
  /// If the request fails, keeps [CurrencyDisplay.defaultEgpToKrwRate].
  Future<void> loadEgpToKrwOnceOnAppLaunch() async {
    if (_didLoadAtAppLaunch) return;
    _didLoadAtAppLaunch = true;

    try {
      final response = await _dio.get(
        _endpoint,
        queryParameters: const {'base': 'EGP', 'symbols': 'KRW'},
      );
      final rate = _parseRate(response.data);
      if (rate != null) {
        CurrencyDisplay.setEgpToKrwRate(rate);
      }
    } catch (_) {
      // Keep fallback rate.
    }
  }

  double? _parseRate(dynamic data) {
    if (data is! Map) return null;
    final rates = data['rates'];
    if (rates is! Map) return null;
    final krw = rates['KRW'];
    if (krw is! num) return null;
    final rate = krw.toDouble();
    if (rate <= 0) return null;
    return rate;
  }
}
