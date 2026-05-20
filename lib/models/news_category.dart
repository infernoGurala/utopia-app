class NewsCategory {
  final String slug;
  final String label;
  final int displayOrder;

  NewsCategory({
    required this.slug,
    required this.label,
    required this.displayOrder,
  });

  /// Parse from Supabase row or cache Map
  factory NewsCategory.fromMap(Map<String, dynamic> map) {
    return NewsCategory(
      slug: map['slug']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      displayOrder: map['display_order'] is int 
          ? map['display_order'] as int 
          : int.tryParse(map['display_order']?.toString() ?? '0') ?? 0,
    );
  }

  /// Serialize to Map for database/cache storage
  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'label': label,
      'display_order': displayOrder,
    };
  }
}
