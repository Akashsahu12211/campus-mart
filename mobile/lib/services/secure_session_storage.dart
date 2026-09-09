import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStorage {
  static const String accessTokenKey = 'campusmart_token';
  static const String refreshTokenKey = 'campusmart_refresh_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static Future<String?> readAccessToken() =>
      _storage.read(key: accessTokenKey);

  static Future<String?> readRefreshToken() =>
      _storage.read(key: refreshTokenKey);

  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: refreshTokenKey, value: refreshToken);
    } else {
      await _storage.delete(key: refreshTokenKey);
    }
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
  }
}
