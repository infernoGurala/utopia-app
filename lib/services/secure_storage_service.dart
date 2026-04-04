import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _rollKey = 'attendance_roll';
  static const String _passwordKey = 'attendance_pwd';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveCredentials(
    String rollNumber,
    String password,
  ) async {
    await _storage.write(key: _rollKey, value: rollNumber.trim());
    await _storage.write(key: _passwordKey, value: password);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final rollNumber = await _storage.read(key: _rollKey);
    final password = await _storage.read(key: _passwordKey);
    if (rollNumber == null || password == null) {
      return null;
    }
    return {'rollNumber': rollNumber, 'password': password};
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _rollKey);
    await _storage.delete(key: _passwordKey);
  }
}
