enum CardType { swipe, active }
enum SessionStatus { pending, inProgress, completed }
enum ActiveCardResult { pending, passed, failed }

class SessionCard {
  final String wordId;
  final CardType type;
  bool isCompleted;
  ActiveCardResult result;

  SessionCard({
    required this.wordId,
    required this.type,
    this.isCompleted = false,
    this.result = ActiveCardResult.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'wordId': wordId,
      'type': type.index,
      'isCompleted': isCompleted,
      'result': result.index,
    };
  }

  factory SessionCard.fromJson(Map<String, dynamic> json) {
    return SessionCard(
      wordId: json['wordId'],
      type: CardType.values[json['type']],
      isCompleted: json['isCompleted'] ?? false,
      result: ActiveCardResult.values[json['result'] ?? 0],
    );
  }
}

class Session {
  final String id;
  final String deckId;
  final int day;
  final DateTime date;
  final List<SessionCard> cards;
  SessionStatus status;

  Session({
    required this.id,
    required this.deckId,
    required this.day,
    required this.date,
    required this.cards,
    this.status = SessionStatus.pending,
  });

  int get completedCards => cards.where((c) => c.isCompleted).length;
  bool get isFinished => completedCards == cards.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deckId': deckId,
      'day': day,
      'date': date.toIso8601String(),
      'cards': cards.map((c) => c.toJson()).toList(),
      'status': status.index,
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      deckId: json['deckId'],
      day: json['day'],
      date: DateTime.parse(json['date']),
      cards: (json['cards'] as List).map((c) => SessionCard.fromJson(c)).toList(),
      status: SessionStatus.values[json['status'] ?? 0],
    );
  }
}
