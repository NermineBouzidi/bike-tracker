import 'package:dio/dio.dart';
import '../../core/api_config.dart';
import '../auth/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient(this._storage)
      : _dio = Dio(_options()),
        _plain = Dio(_options());

  static BaseOptions _options() => BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      );

  final TokenStorage _storage;
  final Dio _dio;
  final Dio _plain; // used for /auth/refresh
  String? accessToken;
  Future<bool>? _refreshing;

  static const _friendly = {
    'VALIDATION': 'Please check the fields you entered.',
    'TOO_MANY_REQUESTS': 'Too many attempts. Try again in a few minutes.',
    'INVALID_CREDENTIALS': 'Email or password is incorrect.',
    'EMAIL_NOT_VERIFIED': 'Please verify your email first.',
    'EMAIL_TAKEN': 'This email is already registered.',
    'INVALID_CODE': 'The code is invalid or has expired.',
    'UNAUTHORIZED': 'Please sign in again.',
    'INVALID_OR_EXPIRED_TOKEN': 'Please sign in again.',
  };

  Future<dynamic> send(String method, String path,
      {Object? data, bool auth = false}) async {
    try {
      return await _request(method, path, data, auth);
    } on DioException catch (e) {
      if (auth && e.response?.statusCode == 401 && await _refresh()) {
        try {
          return await _request(method, path, data, auth);
        } on DioException catch (e2) {
          throw _toApi(e2);
        }
      }
      throw _toApi(e);
    }
  }

  Future<dynamic> _request(String method, String path, Object? data, bool auth) async {
    final res = await _dio.request(
      path,
      data: data,
      options: Options(
        method: method,
        headers: (auth && accessToken != null)
            ? {'Authorization': 'Bearer $accessToken'}
            : null,
      ),
    );
    return res.data;
  }

  // Only one refresh at a time: the server treats a reused refresh token as stolen.
  Future<bool> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final rt = await _storage.readRefresh();
    if (rt == null) return false;
    try {
      final res = await _plain.post('/auth/refresh', data: {'refreshToken': rt});
      final d = res.data as Map<String, dynamic>;
      accessToken = d['accessToken'] as String;
      await _storage.saveRefresh(d['refreshToken'] as String);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        accessToken = null;
        await _storage.clear();
      }
      return false;
    }
  }

  ApiException _toApi(DioException e) {
    final r = e.response;
    if (r == null) {
      return ApiException('NETWORK', 'Cannot reach the server. Check your connection.');
    }
    final body = r.data;
    final code = (body is Map && body['error'] is String)
        ? body['error'] as String
        : 'UNKNOWN';
    final serverMsg =
        (body is Map && body['message'] is String) ? body['message'] as String : null;
    return ApiException(
      code,
      serverMsg ?? _friendly[code] ?? 'Something went wrong. Please try again.',
      statusCode: r.statusCode,
    );
  }
}