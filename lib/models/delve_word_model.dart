class Word {
  final String id;
  final String word;
  final String meaning;
  final String? aiMeaning;
  final String? note;
  final String? partOfSpeech;
  final DateTime addedAt;
  final DateTime? archivedAt;
  final int failCount;

  Word({
    required this.id,
    required this.word,
    required this.meaning,
    this.aiMeaning,
    this.note,
    this.partOfSpeech,
    required this.addedAt,
    this.archivedAt,
    this.failCount = 0,
  });

  Word copyWith({
    String? word,
    String? meaning,
    String? aiMeaning,
    String? note,
    String? partOfSpeech,
    int? failCount,
    DateTime? archivedAt,
  }) {
    return Word(
      id: id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      aiMeaning: aiMeaning ?? this.aiMeaning,
      note: note ?? this.note,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      addedAt: addedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      failCount: failCount ?? this.failCount,
    );
  }

  bool get isArchived => archivedAt != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'aiMeaning': aiMeaning,
      'note': note,
      'partOfSpeech': partOfSpeech,
      'addedAt': addedAt.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
      'failCount': failCount,
    };
  }

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'],
      word: json['word'],
      meaning: json['meaning'],
      aiMeaning: json['aiMeaning'],
      note: json['note'],
      partOfSpeech: json['partOfSpeech'],
      addedAt: DateTime.parse(json['addedAt']),
      archivedAt: json['archivedAt'] != null ? DateTime.parse(json['archivedAt']) : null,
      failCount: json['failCount'] ?? 0,
    );
  }
}
