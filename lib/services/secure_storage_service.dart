import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _rollKey = 'attendance_roll';
  static const String _passwordKey = 'attendance_pwd';
  static const String _collegeKey = 'college';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

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
}
