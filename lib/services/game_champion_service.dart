import 'package:cloud_firestore/cloud_firestore.dart';

class GameChampionService {
  GameChampionService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Map<String, int> _topScoreRanksFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rankedDocs =
        snapshot.docs
            .where((doc) => (doc.data()['totalScore'] as num?)?.toInt() != null)
            .toList()
          ..sort((a, b) {
            final scoreA = (a.data()['totalScore'] as num?)?.toInt() ?? 0;
            final scoreB = (b.data()['totalScore'] as num?)?.toInt() ?? 0;
            if (scoreA != scoreB) return scoreB.compareTo(scoreA);
            final tsA = (a.data()['scoreTimestamp'] as num?)?.toInt() ?? 0;
            final tsB = (b.data()['scoreTimestamp'] as num?)?.toInt() ?? 0;
            return tsA.compareTo(tsB);
          });

    final result = <String, int>{};
    var nextRank = 1;
    for (final doc in rankedDocs) {
      final score = (doc.data()['totalScore'] as num?)?.toInt() ?? 0;
      if (score <= 0) continue;
      result[doc.id] = nextRank;
      nextRank += 1;
      if (nextRank > 3) break;
    }
    return result;
  }

  static String _todayDateIST() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayDateIST() {
    final yesterday = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 1))
        .add(const Duration(hours: 5, minutes: 30));
    return '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  /// Returns true if lastPlayedDate is today or yesterday (streak is alive).
  static bool _isStreakActive(String? lastPlayedDate) {
    if (lastPlayedDate == null || lastPlayedDate.isEmpty) return false;
    return lastPlayedDate == _todayDateIST() ||
        lastPlayedDate == _yesterdayDateIST();
  }

  /// Returns the effective streak for a Firestore score doc.
  /// If the user hasn't played today or yesterday, their streak is 0 (expired).
  static int getEffectiveStreak(Map<String, dynamic> data) {
    final lastPlayed = data['lastPlayedDate'] as String?;
    if (!_isStreakActive(lastPlayed)) return 0;
    return (data['streak'] as num?)?.toInt() ?? 0;
  }

  static Map<String, int> _topStreakRanksFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rankedDocs =
        snapshot.docs
            .where((doc) {
              final streak = (doc.data()['streak'] as num?)?.toInt() ?? 0;
              if (streak <= 0) return false;
              // Only count streaks that are still active
              return _isStreakActive(doc.data()['lastPlayedDate'] as String?);
            })
            .toList()
          ..sort((a, b) {
            final streakA = (a.data()['streak'] as num?)?.toInt() ?? 0;
            final streakB = (b.data()['streak'] as num?)?.toInt() ?? 0;
            if (streakA != streakB) return streakB.compareTo(streakA);
            final tsA = (a.data()['streakTimestamp'] as num?)?.toInt() ?? 0;
            final tsB = (b.data()['streakTimestamp'] as num?)?.toInt() ?? 0;
            return tsA.compareTo(tsB);
          });

    final result = <String, int>{};
    var nextRank = 1;
    for (final doc in rankedDocs) {
      result[doc.id] = nextRank;
      nextRank += 1;
      if (nextRank > 3) break;
    }
    return result;
  }

  static Stream<Map<String, int>> topScoreRanksStream() {
    return _firestore
        .collection('sciwordle_scores')
        .snapshots()
        .map(_topScoreRanksFromSnapshot);
  }

  static Stream<Map<String, int>> topStreakRanksStream() {
    return _firestore
        .collection('sciwordle_scores')
        .snapshots()
        .map(_topStreakRanksFromSnapshot);
  }

  static Stream<String?> legendUidStream() {
    return topScoreRanksStream().map((ranks) {
      for (final entry in ranks.entries) {
        if (entry.value == 1) return entry.key;
      }
      return null;
    });
  }

  static Stream<String?> goatUidStream() {
    return topStreakRanksStream().map((ranks) {
      for (final entry in ranks.entries) {
        if (entry.value == 1) return entry.key;
      }
      return null;
    });
  }

  static Future<String?> syncChampion() async {
    final usersSnapshot = await _firestore.collection('sciwordle_scores').get();
    String? championUid;
    var championScore = 0;
    var championScoreTimestamp = 9223372036854775807;

    for (final doc in usersSnapshot.docs) {
      final score = (doc.data()['totalScore'] as num?)?.toInt() ?? 0;
      final scoreTimestamp =
          (doc.data()['scoreTimestamp'] as num?)?.toInt() ??
          9223372036854775807;
      if (score > championScore) {
        championUid = doc.id;
        championScore = score;
        championScoreTimestamp = scoreTimestamp;
        continue;
      }
      if (score == championScore &&
          score > 0 &&
          championUid != null &&
          scoreTimestamp < championScoreTimestamp) {
        championUid = doc.id;
        championScoreTimestamp = scoreTimestamp;
      }
      if (score > 0 && championUid == null) {
        championUid = doc.id;
        championScoreTimestamp = scoreTimestamp;
      }
    }

    return championScore > 0 ? championUid : null;
  }
}
