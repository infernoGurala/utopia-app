import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class BroadcastService {
  static Future<void> sendBroadcast({
    required String title,
    required String message,
    required String senderName,
  }) async {
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('github')
          .get();
      final data = configDoc.data();
      final pat = data?['pat'] as String?;

      if (pat == null || pat.isEmpty) {
        throw Exception('GitHub token is missing.');
      }

      final uri = Uri.parse(
        'https://api.github.com/repos/'
        'infernoGurala/utopia-content'
        '/actions/workflows/broadcast.yml/dispatches',
      );

      final body = jsonEncode({
        'ref': 'main',
        'inputs': {
          'title': title,
          'message': message,
          'sender': senderName,
        },
      });

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $pat',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 204) {
        throw Exception('GitHub API error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
