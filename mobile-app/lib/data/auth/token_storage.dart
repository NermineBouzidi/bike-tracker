import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _refreshKey = 'refresh_token';
  final _storage = const FlutterSecureStorage();

  Future<String?> readRefresh() => _storage.read(key: _refreshKey);
  Future<void> saveRefresh(String token) =>
      _storage.write(key: _refreshKey, value: token);
  Future<void> clear() => _storage.delete(key: _refreshKey);
}