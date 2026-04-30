import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
class WriterFirestoreService {
  static Future<Map<String, dynamic>?> fetchConfig(String configName) async {
    if (configName == 'timetable') {
      try {
        final url = Uri.parse('https://raw.githubusercontent.com/infernoGurala/utopia-content/main/timetable.json');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        print('Error fetching old timetable from GitHub: $e');
      }
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc(configName).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch config $configName: $e');
    }
  }

  static Future<void> updateConfig(String configName, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('config').doc(configName).set(data);
    } catch (e) {
      throw Exception('Failed to update config $configName: $e');
    }
  }
}
