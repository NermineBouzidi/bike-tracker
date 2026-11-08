import '../../domain/app_user.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'token_storage.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  /// Returns true if the server managed to send the verification email.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final d = await _api.send('POST', '/auth/register', data: {
      'displayName': name,
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    return d['emailSent'] as bool? ?? true;
  }

  Future<void> verifyEmail({required String email, required String code}) =>
      _api.send('POST', '/auth/verify-email', data: {'email': email, 'code': code});

  Future<void> resendVerification(String email) =>
      _api.send('POST', '/auth/resend-verification', data: {'email': email});

  Future<AppUser> login({required String email, required String password}) async {
    final d = await _api.send('POST', '/auth/login',
        data: {'email': email, 'password': password}) as Map<String, dynamic>;
    _api.accessToken = d['accessToken'] as String;
    await _storage.saveRefresh(d['refreshToken'] as String);
    return AppUser.fromJson(d['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final rt = await _storage.readRefresh();
    try {
      if (rt != null) {
        await _api.send('POST', '/auth/logout', data: {'refreshToken': rt});
      }
    } on ApiException {
      // signing out locally anyway
    } finally {
      _api.accessToken = null;
      await _storage.clear();
    }
  }

  Future<void> forgotPassword(String email) =>
      _api.send('POST', '/auth/forgot-password', data: {'email': email});

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _api.send('POST', '/auth/reset-password',
          data: {'email': email, 'code': code, 'newPassword': newPassword});

  Future<AppUser> me() async {
    final d = await _api.send('GET', '/me', auth: true) as Map<String, dynamic>;
    return AppUser.fromJson(d);
  }
}