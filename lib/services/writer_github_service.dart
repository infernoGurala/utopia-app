import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'github_service.dart';

class WriterGitHubService {
  static String get owner => GitHubService.owner;
  static String get repo => GitHubService.repo;
  static String get branch => GitHubService.branch;
  static String? _cachedPat;

  static String rawUrl(String filename) =>
      'https://raw.githubusercontent.com/$owner/$repo/$branch/$filename'
      '?cb=${DateTime.now().millisecondsSinceEpoch}';

  static String contentsUrl(String filename) =>
      'https://api.github.com/repos/$owner/$repo/contents/$filename';

  static Future<String> fetchPat() async {
    if (_cachedPat != null && _cachedPat!.isNotEmpty) {
      return _cachedPat!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('github')
          .get();
      final pat = doc.data()?['pat'] as String?;
      if (pat == null || pat.isEmpty) {
        throw Exception('GitHub token is missing.');
      }
      _cachedPat = pat;
      return pat;
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> fetchRawJson(String filename) async {
    try {
      final url = rawUrl(filename);
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load $filename.');
      }
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<GitHubFileData> fetchFileData(String filename) async {
    try {
      final pat = await fetchPat();
      final url = contentsUrl(filename);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $pat',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load file metadata for $filename.');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sha = body['sha'] as String?;
      final content = body['content'] as String?;
      if (sha == null || sha.isEmpty || content == null) {
        throw Exception('GitHub response missing file content or sha.');
      }

      final decoded = utf8.decode(base64.decode(content.replaceAll('\n', '')));
      final jsonData = jsonDecode(decoded);
      return GitHubFileData(
        sha: sha,
        jsonData: jsonData,
        rawBody: response.body,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> fetchFileSha(String filename) async {
    try {
      final pat = await fetchPat();
      final url = contentsUrl(filename);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $pat',
          'Accept': 'application/vnd.github+json',
        },
      );
      if (response.statusCode != 200) {
        throw Exception(_buildGitHubError(
          action: 'fetch file SHA',
          filename: filename,
          response: response,
        ));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sha = body['sha'] as String?;
      if (sha == null || sha.isEmpty) {
        throw Exception('File SHA missing for $filename.');
      }
      return sha;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateJsonFile({
    required String filename,
    required dynamic jsonData,
    required String commitMessage,
  }) async {
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    await updateTextFile(
      filename: filename,
      content: jsonString,
      commitMessage: commitMessage,
    );
  }

  static Future<void> updateTextFile({
    required String filename,
    required String content,
    required String commitMessage,
  }) async {
    try {
      final pat = await fetchPat();
      final currentSha = await fetchFileSha(filename);
      final encodedContent = base64.encode(utf8.encode(content));
      final url = contentsUrl(filename);
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $pat',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': commitMessage,
          'content': encodedContent,
          'sha': currentSha,
          'branch': branch,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_buildGitHubError(
          action: 'update file',
          filename: filename,
          response: response,
        ));
      }
    } catch (e) {
      rethrow;
    }
  }

  static String _buildGitHubError({
    required String action,
    required String filename,
    required http.Response response,
  }) {
    String? details;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message']?.toString().trim();
        final errors = body['errors'];
        if (errors is List && errors.isNotEmpty) {
          final joinedErrors = errors
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .join(', ');
          details = [message, joinedErrors]
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .join(' | ');
        } else {
          details = message;
        }
      }
    } catch (_) {
      details = null;
    }

    final suffix = details == null || details.isEmpty ? '' : ': $details';
    return 'GitHub $action failed for $filename '
        '(${response.statusCode})$suffix';
  }
}

class GitHubFileData {
  GitHubFileData({
    required this.sha,
    required this.jsonData,
    required this.rawBody,
  });

  final String sha;
  final dynamic jsonData;
  final String rawBody;
}
