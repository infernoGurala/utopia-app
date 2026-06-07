enum DeckStatus { active, waiting, testDay, completed }

class Deck {
  final String id;
  final DateTime startedAt;
  final int currentDay; // 1 to 13
  final DeckStatus status;
  final List<String> set1WordIds; // 5 cards
  final List<String> set2WordIds; // 5 cards
  final List<String> set3WordIds; // 5 cards
  final DateTime? lastSessionDate; // When the last session was completed

  Deck({
    required this.id,
    required this.startedAt,
    required this.currentDay,
    required this.status,
    required this.set1WordIds,
    required this.set2WordIds,
    required this.set3WordIds,
    this.lastSessionDate,
  });

  List<String> get allWordIds => [...set1WordIds, ...set2WordIds, ...set3WordIds];

  /// Check if today's session has already been completed.
  bool get isSessionCompletedToday {
    if (lastSessionDate == null) return false;
    final now = DateTime.now();
    return lastSessionDate!.year == now.year &&
        lastSessionDate!.month == now.month &&
        lastSessionDate!.day == now.day;
  }

  /// Check if the user missed a day (last session was before yesterday).
  bool get hasMissedDay {
    if (lastSessionDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastSession = DateTime(
      lastSessionDate!.year,
      lastSessionDate!.month,
      lastSessionDate!.day,
    );
    // If more than 1 day has passed since last session, the user missed a day
    return today.difference(lastSession).inDays > 1;
  }

  /// Check if it's a new day (yesterday was last session → ready for next day).
  bool get isNewDayReady {
    if (lastSessionDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastSession = DateTime(
      lastSessionDate!.year,
      lastSessionDate!.month,
      lastSessionDate!.day,
    );
    return today.difference(lastSession).inDays == 1;
  }

  Deck copyWith({
    int? currentDay,
    DeckStatus? status,
    DateTime? lastSessionDate,
  }) {
    return Deck(
      id: id,
      startedAt: startedAt,
      currentDay: currentDay ?? this.currentDay,
      status: status ?? this.status,
      set1WordIds: set1WordIds,
      set2WordIds: set2WordIds,
      set3WordIds: set3WordIds,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'currentDay': currentDay,
      'status': status.index,
      'set1WordIds': set1WordIds,
      'set2_word_ids': set2WordIds, // Match database naming in json encoding if needed
      'set3_word_ids': set3WordIds,
      'lastSessionDate': lastSessionDate?.toIso8601String(),
    };
  }

  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck(
      id: json['id'],
      startedAt: DateTime.parse(json['startedAt']),
      currentDay: json['currentDay'],
      status: DeckStatus.values[json['status']],
      set1WordIds: List<String>.from(json['set1WordIds'] ?? json['set1_word_ids'] ?? []),
      set2WordIds: List<String>.from(json['set2WordIds'] ?? json['set2_word_ids'] ?? []),
      set3WordIds: List<String>.from(json['set3WordIds'] ?? json['set3_word_ids'] ?? []),
      lastSessionDate: json['lastSessionDate'] != null
          ? DateTime.parse(json['lastSessionDate'])
          : (json['last_session_date'] != null ? DateTime.parse(json['last_session_date']) : null),
    );
  }
}
