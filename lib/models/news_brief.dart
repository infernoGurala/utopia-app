class NewsBrief {
  final String id;
  final String category;
  final String sourceName;
  final String originalTitle;
  final String headline;
  final String keyFact;
  final String summary;
  final DateTime publishedAt;
  final String fetchedDate;
  final DateTime? fetchedAt;
  final int displayOrder;
  final bool isActive;
  final String? imageUrl;

  NewsBrief({
    required this.id,
    required this.category,
    required this.sourceName,
    required this.originalTitle,
    required this.headline,
    required this.keyFact,
    required this.summary,
    required this.publishedAt,
    required this.fetchedDate,
    this.fetchedAt,
    required this.displayOrder,
    this.isActive = true,
    this.imageUrl,
  });

  /// Parse from Supabase row or cache Map
  factory NewsBrief.fromMap(Map<String, dynamic> map) {
    return NewsBrief(
      id: map['id']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      sourceName: map['source_name']?.toString() ?? '',
      originalTitle: map['original_title']?.toString() ?? '',
      headline: map['headline']?.toString() ?? '',
      keyFact: map['key_fact']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      publishedAt: map['published_at'] != null 
          ? DateTime.tryParse(map['published_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fetchedDate: map['fetched_date']?.toString() ?? '',
      fetchedAt: map['fetched_at'] != null
          ? DateTime.tryParse(map['fetched_at'].toString())
          : null,
      displayOrder: map['display_order'] is int 
          ? map['display_order'] as int 
          : int.tryParse(map['display_order']?.toString() ?? '0') ?? 0,
      isActive: map['is_active'] == true || map['is_active'] == 1,
      imageUrl: map['image_url']?.toString(),
    );
  }

  /// Serialize to Map for database/cache storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'source_name': sourceName,
      'original_title': originalTitle,
      'headline': headline,
      'key_fact': keyFact,
      'summary': summary,
      'published_at': publishedAt.toIso8601String(),
      'fetched_date': fetchedDate,
      'fetched_at': fetchedAt?.toIso8601String(),
      'display_order': displayOrder,
      'is_active': isActive ? 1 : 0,
      'image_url': imageUrl,
    };
  }
}
