import 'package:shared_preferences/shared_preferences.dart';

/// Stores which attendance server to use.
///   server1 = In-App (on-device scraping via AUS/ACET services)
///   server2 = Cloud  (Cloudflare Worker at attendance-api.inferalis.space)
class AttendanceServerPreference {
  static const String kServer1 = 'server1';
  static const String kServer2 = 'server2';

  static const String _key = 'attendance_server';

  /// Returns the saved server preference, defaulting to server1.
  static Future<String> getServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? kServer1;
  }

  /// Persists the server preference.
  static Future<void> setServer(String server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, server);
  }
}
