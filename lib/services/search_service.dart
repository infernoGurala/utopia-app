import 'cache_service.dart';

class SearchResult {
  final String subject;
  final String topic;
  final String topicPath;
  final String folderPath;
  final String preview;
  SearchResult({
    required this.subject,
    required this.topic,
    required this.topicPath,
    required this.folderPath,
    required this.preview,
  });
}

class SearchService {
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().length < 2) return [];
    final results = await CacheService().searchNotes(query);
    return results.map((r) => SearchResult(
      subject: r['subject'] ?? '',
      topic: r['name'] ?? '',
      topicPath: r['path'] ?? '',
      folderPath: r['folder_path'] ?? '',
      preview: r['preview'] ?? '',
    )).toList();
  }
}
