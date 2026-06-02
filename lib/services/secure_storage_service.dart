import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _rollKey = 'attendance_roll';
  static const String _passwordKey = 'attendance_pwd';
  static const String _collegeKey = 'college';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _googleAccessTokenKey = 'google_calendar_access_token';
  static const String _googleRefreshTokenKey = 'google_calendar_refresh_token';
  static const String _googleTokenExpiryKey = 'google_calendar_token_expiry';

  static Future<void> saveCredentials(
    String rollNumber,
    String password,
    String college,
  ) async {
    await _storage.write(key: _rollKey, value: rollNumber.trim());
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _collegeKey, value: college);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final rollNumber = await _storage.read(key: _rollKey);
    final password = await _storage.read(key: _passwordKey);
    final college = await _storage.read(key: _collegeKey);
    if (rollNumber == null || password == null) {
      return null;
    }
    return {
      'rollNumber': rollNumber,
      'password': password,
      'college': college ?? 'aus',
    };
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _rollKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _collegeKey);
  }

  static Future<void> saveGoogleTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiry,
  }) async {
    await _storage.write(key: _googleAccessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _googleRefreshTokenKey, value: refreshToken);
    }
    if (expiry != null) {
      await _storage.write(
        key: _googleTokenExpiryKey,
        value: expiry.millisecondsSinceEpoch.toString(),
      );
    }
  }

  static Future<String?> getGoogleAccessToken() async {
    return await _storage.read(key: _googleAccessTokenKey);
  }

  static Future<String?> getGoogleRefreshToken() async {
    return await _storage.read(key: _googleRefreshTokenKey);
  }

  static Future<DateTime?> getGoogleTokenExpiry() async {
    final val = await _storage.read(key: _googleTokenExpiryKey);
    if (val == null) return null;
    final ms = int.tryParse(val);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> clearGoogleTokens() async {
    await _storage.delete(key: _googleAccessTokenKey);
    await _storage.delete(key: _googleRefreshTokenKey);
    await _storage.delete(key: _googleTokenExpiryKey);
  }
}
