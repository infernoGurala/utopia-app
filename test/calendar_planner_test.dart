import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

String sanitizeJson(String jsonStr) {
  final sb = StringBuffer();
  bool inString = false;
  bool escaped = false;
  for (int i = 0; i < jsonStr.length; i++) {
    final char = jsonStr[i];
    if (char == '"' && !escaped) {
      inString = !inString;
      sb.write(char);
    } else if (char == '\n' && inString) {
      sb.write('\\n');
    } else if (char == '\r' && inString) {
      sb.write('\\r');
    } else {
      sb.write(char);
    }

    if (char == '\\') {
      escaped = !escaped;
    } else {
      escaped = false;
    }
  }
  return sb.toString();
}

Map<String, dynamic>? parseResponse(String responseText) {
  String jsonString = responseText.trim();
  final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false);
  final match = jsonRegex.firstMatch(responseText);
  if (match != null) {
    jsonString = match.group(1)!.trim();
  } else {
    final startIdx = responseText.indexOf('{');
    final endIdx = responseText.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      jsonString = responseText.substring(startIdx, endIdx + 1).trim();
    }
  }

  try {
    final sanitized = sanitizeJson(jsonString);
    return jsonDecode(sanitized) as Map<String, dynamic>;
  } catch (_) {
    // Try regex explanation extraction
    final expRegex = RegExp(r'"explanation"\s*:\s*"([\s\S]*?)"\s*,\s*"actions"', caseSensitive: false);
    final expMatch = expRegex.firstMatch(jsonString);
    if (expMatch != null) {
      final expText = expMatch.group(1)!;
      final cleanText = expText
          .replaceAll('\\n', '\n')
          .replaceAll('\\r', '\r')
          .replaceAll('\\"', '"')
          .replaceAll('\\\\', '\\');
      return {
        'explanation': cleanText,
        'actions': []
      };
    }
    
    // Fallback: raw response is explanation
    return {
      'explanation': responseText,
      'actions': []
    };
  }
}

void main() {
  group('Calendar Planner Response Parser Tests', () {
    test('Should parse clean JSON code block', () {
      final response = '''
Here is the plan for you:
```json
{
  "explanation": "I have planned it.",
  "actions": []
}
```
Let me know if this works!
''';
      final parsed = parseResponse(response);
      expect(parsed, isNotNull);
      expect(parsed!['explanation'], 'I have planned it.');
      expect(parsed['actions'], isEmpty);
    });

    test('Should parse raw JSON string', () {
      final response = '{"explanation": "Raw json test.", "actions": []}';
      final parsed = parseResponse(response);
      expect(parsed, isNotNull);
      expect(parsed!['explanation'], 'Raw json test.');
    });

    test('Should parse JSON wrapped in explanation text', () {
      final response = '''
No code blocks here but:
{
  "explanation": "No block.",
  "actions": [{"action": "create"}]
}
Hope you like it!
''';
      final parsed = parseResponse(response);
      expect(parsed, isNotNull);
      expect(parsed!['explanation'], 'No block.');
      expect(parsed['actions'][0]['action'], 'create');
    });

    test('Should parse JSON with raw newlines inside string values (Sanitizer Test)', () {
      final response = '''
{
  "explanation": "Here are your events:
* Math Class
* Chemistry Class
Please review them.",
  "actions": []
}
''';
      final parsed = parseResponse(response);
      expect(parsed, isNotNull);
      expect(parsed!['explanation'], contains('Here are your events:\n* Math Class\n* Chemistry Class'));
    });

    test('Should fallback to regex explanation extraction for invalid JSON syntax', () {
      final response = '''
{
  "explanation": "Extracted despite actions list syntax error.",
  "actions": [
    {
      "action": "create"
      "summary": "Missing comma before this line"
    }
  ]
}
''';
      final parsed = parseResponse(response);
      expect(parsed, isNotNull);
      expect(parsed!['explanation'], 'Extracted despite actions list syntax error.');
      expect(parsed['actions'], isEmpty);
    });

    test('Should fallback to raw response if not JSON format at all', () {
      final response = 'Hello this is not JSON at all.';
      final parsed = parseResponse(response);
      expect(parsed, isNotNull);
      expect(parsed!['explanation'], 'Hello this is not JSON at all.');
      expect(parsed['actions'], isEmpty);
    });
  });
}
