import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/generated_env.dart';

class AuthSessionService {
  static const _accessTokenKey = 'supabase_access_token';
  static const _refreshTokenKey = 'supabase_refresh_token';
  static const _expiresAtKey = 'supabase_access_token_expires_at';
  static const _userIdKey = 'supabase_user_id';
  static const _expiryMarginSeconds = 60;

  static final AuthSessionService instance = AuthSessionService();

  final Dio _dio;
  final Future<SharedPreferences> Function() _prefsProvider;
  final String _supabaseUrl;
  final String _publishableKey;

  _StoredAuthSession? _cachedSession;
  Future<_StoredAuthSession>? _sessionRequest;

  AuthSessionService({
    Dio? dio,
    Future<SharedPreferences> Function()? prefsProvider,
    String? supabaseUrl,
    String? publishableKey,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 8),
             ),
           ),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _supabaseUrl = (supabaseUrl ?? GeneratedEnv.supabaseUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _publishableKey = publishableKey ?? GeneratedEnv.supabasePublishableKey;

  bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _publishableKey.isNotEmpty;

  Future<String> getAccessToken() async {
    return (await _ensureSession()).accessToken;
  }

  Future<String> getUserId() async {
    return (await _ensureSession()).userId;
  }

  Future<void> clearSession() async {
    _cachedSession = null;
    final prefs = await _prefsProvider();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_expiresAtKey),
      prefs.remove(_userIdKey),
    ]);
  }

  Future<_StoredAuthSession> _ensureSession() {
    final currentRequest = _sessionRequest;
    if (currentRequest != null) return currentRequest;

    final request = _loadOrCreateSession();
    _sessionRequest = request;
    return request.whenComplete(() {
      if (identical(_sessionRequest, request)) {
        _sessionRequest = null;
      }
    });
  }

  Future<_StoredAuthSession> _loadOrCreateSession() async {
    if (!isConfigured) {
      throw StateError(
        'Supabase Auth is not configured. Set SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY before generating Flutter config.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cached = _cachedSession ?? await _readSession();
    if (cached != null && cached.expiresAt > now + _expiryMarginSeconds) {
      _cachedSession = cached;
      return cached;
    }

    if (cached?.refreshToken.isNotEmpty ?? false) {
      try {
        return await _refresh(cached!.refreshToken);
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode;
        if (statusCode != 400 && statusCode != 401) rethrow;
        await clearSession();
      }
    }

    return _signInAnonymously();
  }

  Future<_StoredAuthSession> _signInAnonymously() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_supabaseUrl/auth/v1/signup',
      data: const {
        'data': <String, dynamic>{},
        'gotrue_meta_security': <String, dynamic>{'captcha_token': null},
      },
      options: Options(headers: _authHeaders),
    );
    return _persistResponse(response.data);
  }

  Future<_StoredAuthSession> _refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_supabaseUrl/auth/v1/token',
      queryParameters: const {'grant_type': 'refresh_token'},
      data: {'refresh_token': refreshToken},
      options: Options(headers: _authHeaders),
    );
    return _persistResponse(response.data);
  }

  Map<String, String> get _authHeaders => {
    'apikey': _publishableKey,
    'Authorization': 'Bearer $_publishableKey',
  };

  Future<_StoredAuthSession> _persistResponse(
    Map<String, dynamic>? data,
  ) async {
    if (data == null) {
      throw const FormatException('Supabase Auth returned an empty response.');
    }

    final accessToken = data['access_token'] as String? ?? '';
    final refreshToken = data['refresh_token'] as String? ?? '';
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 0;
    final user = data['user'];
    final userId = user is Map ? user['id'] as String? ?? '' : '';
    if (accessToken.isEmpty ||
        refreshToken.isEmpty ||
        expiresIn <= 0 ||
        userId.isEmpty) {
      throw const FormatException('Supabase Auth returned an invalid session.');
    }

    final session = _StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn,
      userId: userId,
    );
    final prefs = await _prefsProvider();
    await Future.wait([
      prefs.setString(_accessTokenKey, session.accessToken),
      prefs.setString(_refreshTokenKey, session.refreshToken),
      prefs.setInt(_expiresAtKey, session.expiresAt),
      prefs.setString(_userIdKey, session.userId),
    ]);
    _cachedSession = session;
    return session;
  }

  Future<_StoredAuthSession?> _readSession() async {
    final prefs = await _prefsProvider();
    final accessToken = prefs.getString(_accessTokenKey) ?? '';
    final refreshToken = prefs.getString(_refreshTokenKey) ?? '';
    final expiresAt = prefs.getInt(_expiresAtKey) ?? 0;
    final userId = prefs.getString(_userIdKey) ?? '';
    if (accessToken.isEmpty ||
        refreshToken.isEmpty ||
        expiresAt <= 0 ||
        userId.isEmpty) {
      return null;
    }
    return _StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      userId: userId,
    );
  }
}

class _StoredAuthSession {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final String userId;

  const _StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
  });
}
