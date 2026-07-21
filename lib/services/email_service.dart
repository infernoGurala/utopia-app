import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  static const String _serviceId = 'service_u0i4ddk';
  static const String _templateId = 'template_e9wgr9l';
  static const String _publicKey = 'zlrx3k4uIk-LoSc1Q';

  /// Sends an issue report email via EmailJS API.
  Future<bool> sendIssueReport({
    required String userName,
    required String userEmail,
    required String title,
    required String description,
    required String imageUrls,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'localhost',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'user_name': userName,
            'user_email': userEmail,
            'issue_title': title,
            'issue_description': description,
            'image_urls': imageUrls.isNotEmpty ? imageUrls : 'No images uploaded.',
          },
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('EmailService: Email sent successfully');
        return true;
      } else {
        debugPrint('EmailService: Failed to send email (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('EmailService: Error sending email: $e');
      return false;
    }
  }
}
