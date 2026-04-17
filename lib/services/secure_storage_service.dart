import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/campus.dart';

class SecureStorageService {
  static const String _rollKey = 'attendance_roll';
  static const String _passwordKey = 'attendance_pwd';
  static const String _campusKey = 'attendance_campus';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveCredentials(
    String rollNumber,
    String password,
    Campus campus,
  ) async {
    await _storage.write(key: _rollKey, value: rollNumber.trim());
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _campusKey, value: campus.name);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final rollNumber = await _storage.read(key: _rollKey);
    final password = await _storage.read(key: _passwordKey);
    if (rollNumber == null || password == null) {
      return null;
    }
    final campusName = await _storage.read(key: _campusKey);
    return {
      'rollNumber': rollNumber,
      'password': password,
      'campus': campusName ?? Campus.aus.name,
    };
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _rollKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _campusKey);
  }
}
