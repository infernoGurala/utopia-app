// ignore_for_file: avoid_print

import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const String databaseUrl =
      'https://utopia-app-33cf8-default-rtdb.asia-southeast1.firebasedatabase.app';
  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: databaseUrl,
  );
  static const double _southwestLat = 17.0854;
  static const double _southwestLng = 82.0656;
  static const double _northeastLat = 17.0922;
  static const double _northeastLng = 82.0729;

  static bool isWithinCampusHours() {
    final nowIst = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    return nowIst.hour >= 8 && nowIst.hour < 22;
  }

  static bool isWithinCampusArea(double latitude, double longitude) {
    return latitude >= _southwestLat &&
        latitude <= _northeastLat &&
        longitude >= _southwestLng &&
        longitude <= _northeastLng;
  }

  static Future<void> startSharingLocation(
    String uid,
    String displayName, {
    bool restrictToCampus = false,
  }) async {
    try {
      if (restrictToCampus && !isWithinCampusHours()) {
        print('Location sharing skipped: outside campus hours');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied forever');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      await _database.ref('locations/$uid').set({
        'lat': position.latitude,
        'lng': position.longitude,
        'displayName': displayName.trim().isEmpty
            ? 'UTOPIA Student'
            : displayName.trim(),
        'updatedAt': ServerValue.timestamp,
        'sharing': true,
        'restrictToCampus': restrictToCampus,
      });

      print('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Location sharing error: $e');
      rethrow;
    }
  }

  static Future<void> stopSharingLocation(String uid) async {
    try {
      await _database.ref('locations/$uid/sharing').set(false);
      print('Location sharing stopped');
    } catch (e) {
      print('Stop sharing error: $e');
      rethrow;
    }
  }

  static Future<void> removeLocation(String uid) async {
    try {
      await _database.ref('locations/$uid').remove();
      print('Location removed');
    } catch (e) {
      print('Remove location error: $e');
      rethrow;
    }
  }
}
