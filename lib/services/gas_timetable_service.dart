import 'dart:convert';
import 'package:http/http.dart' as http;

class GasTimetableService {
  static const String _url = 'https://script.google.com/macros/s/AKfycbyjjY4Bh7wv8pMsoTtp2p8qwaY--ryQ5xgrMNhb8EWmmqYj7c7a3RFa_GyADq5O33E/exec';

  static Future<Map<String, dynamic>> fetchTimetable(
    String rollNumber,
    String password,
    String college,
  ) async {
    final trimmedRoll = rollNumber.trim();
    final query = '?rollNumber=$trimmedRoll&password=${Uri.encodeComponent(password)}&college=${Uri.encodeComponent(college)}';
    
    final response = await http.get(Uri.parse('$_url$query'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch timetable');
    }

    final json = jsonDecode(response.body);
    if (json['ok'] != true) {
      throw Exception('Server returned an error');
    }

    return json['data'] as Map<String, dynamic>;
  }
}
