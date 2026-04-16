// lib/services/sciwordle_service.dart
//
// Handles all Firestore reads and writes for SciWordle.
// No screen ever touches Firestore directly — everything goes through here.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sciwordle_model.dart';

class SciwordleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _dailyCol = 'sciwordle_daily';
  static const String _scoresCol = 'sciwordle_scores';
  static const String _progressCol = 'sciwordle_progress';
  static const int _playedGameStreakBonus = 2;

  String getTodayDateIST() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String getYesterdayDateIST() {
    final yesterday = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 1))
        .add(const Duration(hours: 5, minutes: 30));
    final y = yesterday.year.toString().padLeft(4, '0');
    final m = yesterday.month.toString().padLeft(2, '0');
    final d = yesterday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> updateScore({
    required String uid,
    required String name,
    required int wordLength,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('sciwordle_scores')
        .doc(uid);

    final today = getTodayDateIST();
    final doc = await docRef.get();

    int streak = 1;
    int bestStreak = 1;
    int totalScore = 0;
    int gamesPlayed = 0;
    int? scoreTimestamp;
    int? streakTimestamp;

    if (doc.exists) {
      final data = doc.data()!;

      final lastPlayed = (data['lastPlayedDate'] as String?) ?? "";

      streak = (data['streak'] as num?)?.toInt() ?? 0;
      bestStreak = (data['bestStreak'] as num?)?.toInt() ?? 0;
      totalScore = (data['totalScore'] as num?)?.toInt() ?? 0;
      gamesPlayed = (data['gamesPlayed'] as num?)?.toInt() ?? 0;
      scoreTimestamp = (data['scoreTimestamp'] as num?)?.toInt();
      streakTimestamp = (data['streakTimestamp'] as num?)?.toInt();

      if (lastPlayed == today) {
        return;
      } else if (lastPlayed == getYesterdayDateIST()) {
        // Played yesterday → continue the streak
        streak = streak + 1;
      } else {
        // Missed at least one day → reset streak
        streak = 1;
      }

      if (streak > bestStreak) {
        bestStreak = streak;
      }
    }

    final score = 10 + (wordLength * 2) + _playedGameStreakBonus;
    final newTotalScore = totalScore + score;
    final oldStreak = (doc.exists
        ? (doc.data()!['streak'] as num?)?.toInt() ?? 0
        : 0);

    await docRef.set({
      'name': name,
      'streak': streak,
      'bestStreak': bestStreak,
      'totalScore': newTotalScore,
      'lastScore': score,
      'gamesPlayed': gamesPlayed + 1,
      'lastPlayedDate': today,
      'scoreTimestamp': newTotalScore > totalScore
          ? DateTime.now().millisecondsSinceEpoch
          : scoreTimestamp,
      'streakTimestamp': streak > oldStreak
          ? DateTime.now().millisecondsSinceEpoch
          : streakTimestamp,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getLeaderboard() {
    return FirebaseFirestore.instance
        .collection('sciwordle_scores')
        .limit(50)
        .snapshots();
  }

  int _nextStreakForPlayedGame(SciwordlePlayerScore existing) {
    if (existing.gamesPlayed == 0) return 1;
    // Only continue the streak if they played yesterday
    if (existing.lastPlayedDate == getYesterdayDateIST()) {
      return existing.streak + 1;
    }
    // If they already played today (shouldn't reach here due to guard), keep same
    if (existing.lastPlayedDate == todayKey) {
      return existing.streak;
    }
    // Missed a day or more → reset
    return 1;
  }

  /// Returns true if the user's streak is still active (played today or yesterday).
  /// Use this to decide whether to show the fire icon.
  bool isStreakActive(String? lastPlayedDate) {
    if (lastPlayedDate == null || lastPlayedDate.isEmpty) return false;
    return lastPlayedDate == todayKey ||
        lastPlayedDate == getYesterdayDateIST();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Today's Firestore document key, e.g. "2026-04-01"
  String get todayKey => getTodayDateIST();

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not logged in.');
    return user.uid;
  }

  String get _displayName {
    return _auth.currentUser?.displayName ?? 'Student';
  }

  // ─── Fetch today's question ───────────────────────────────────────────────

  /// Returns today's [SciwordleQuestion], or null if not yet generated.
  Future<SciwordleQuestion?> fetchTodaysQuestion() async {
    try {
      final doc = await _db.collection(_dailyCol).doc(todayKey).get();
      if (!doc.exists || doc.data() == null) return null;
      return SciwordleQuestion.fromFirestore(doc.data()!, todayKey);
    } on FirebaseException catch (e) {
      throw Exception("Couldn't load today's question: ${e.message}");
    } catch (_) {
      throw Exception("Something went wrong loading the question. Try again.");
    }
  }

  // ─── Fetch current player's score ─────────────────────────────────────────

  /// Returns the player's score doc, or a clean slate if first time.
  Future<SciwordlePlayerScore> fetchPlayerScore() async {
    try {
      final doc = await _db.collection(_scoresCol).doc(_uid).get();
      if (!doc.exists || doc.data() == null) {
        return SciwordlePlayerScore.empty(_uid);
      }
      return SciwordlePlayerScore.fromFirestore(doc.data()!, _uid);
    } on FirebaseException catch (e) {
      throw Exception("Couldn't load your score: ${e.message}");
    } catch (_) {
      throw Exception("Something went wrong loading your score. Try again.");
    }
  }

  // ─── Save result after a game ─────────────────────────────────────────────

  /// Called exactly once when a game ends.
  /// [attemptNumber] = 1–6 if they won, null if they lost all 6.
  /// Returns the points earned this round (word score + streak bonus).
  Future<int> saveGameResult({required int? attemptNumber}) async {
    try {
      final uid = _uid;
      final today = todayKey;

      // Load existing score
      final doc = await _db.collection(_scoresCol).doc(uid).get();
      final existing = (doc.exists && doc.data() != null)
          ? SciwordlePlayerScore.fromFirestore(doc.data()!, uid)
          : SciwordlePlayerScore.empty(uid);

      // Guard: don't save twice for the same day
      if (existing.lastPlayedDate == today) return 0;

      // ── Word score ──
      // 1st try = 6 pts, 2nd = 5 ... 6th = 1, failed = 0
      final wordScore = attemptNumber != null ? (7 - attemptNumber) : 0;

      // Any completed game counts toward the streak.
      // Missed days pause the streak instead of resetting it.
      final newStreak = _nextStreakForPlayedGame(existing);

      final newBestStreak = newStreak > existing.bestStreak
          ? newStreak
          : existing.bestStreak;

      final streakBonus = _playedGameStreakBonus;

      final roundPoints = wordScore + streakBonus;
      final newTotal = existing.totalScore + roundPoints;

      await _db.collection(_scoresCol).doc(uid).set({
        'name': _displayName,
        'totalScore': newTotal,
        'streak': newStreak,
        'bestStreak': newBestStreak,
        'lastScore': roundPoints,
        'lastPlayedDate': today,
        'gamesPlayed': existing.gamesPlayed + 1,
        'scoreTimestamp': newTotal > existing.totalScore
            ? DateTime.now().millisecondsSinceEpoch
            : existing.scoreTimestamp,
        'streakTimestamp': newStreak > existing.streak
            ? DateTime.now().millisecondsSinceEpoch
            : existing.streakTimestamp,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return roundPoints;
    } on FirebaseException catch (e) {
      throw Exception("Couldn't save your score: ${e.message}");
    } catch (_) {
      throw Exception("Something went wrong saving your score. Try again.");
    }
  }

  // ─── Check if already played today ───────────────────────────────────────

  /// Returns true if the current player has already played today.
  Future<bool> hasPlayedToday() async {
    try {
      final doc = await _db.collection(_scoresCol).doc(_uid).get();
      if (!doc.exists || doc.data() == null) return false;
      final lastPlayed = doc.data()!['lastPlayedDate'] as String? ?? '';
      return lastPlayed == todayKey;
    } catch (_) {
      return false;
    }
  }

  // ─── In-progress guess persistence ────────────────────────────────────────

  /// Saves the current list of guesses so the user can't cheat by backing out.
  Future<void> saveGuessProgress({
    required List<String> guesses,
    required String answer,
  }) async {
    try {
      await _db.collection(_progressCol).doc(_uid).set({
        'dateKey': todayKey,
        'guesses': guesses,
        'answer': answer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silently fail — worst case the user gets a fresh start
    }
  }

  /// Fetches saved in-progress guesses for today, if any.
  /// Returns null if there's no progress for today.
  Future<SciwordleProgressData?> fetchGuessProgress() async {
    try {
      final doc = await _db.collection(_progressCol).doc(_uid).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      final dateKey = data['dateKey'] as String? ?? '';
      if (dateKey != todayKey) return null;
      final guesses = (data['guesses'] as List<dynamic>? ?? [])
          .map((e) => (e as String).toLowerCase())
          .toList();
      final answer = (data['answer'] as String? ?? '').toLowerCase();
      if (guesses.isEmpty || answer.isEmpty) return null;
      return SciwordleProgressData(guesses: guesses, answer: answer);
    } catch (_) {
      return null;
    }
  }

  /// Clears in-progress data (called when the game finishes).
  Future<void> clearGuessProgress() async {
    try {
      await _db.collection(_progressCol).doc(_uid).delete();
    } catch (_) {}
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────────

  /// Fetches all player scores sorted by totalScore descending.
  Future<List<SciwordleLeaderboardEntry>> fetchLeaderboard() async {
    try {
      final snapshot = await _db.collection(_scoresCol).limit(100).get();
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final scoreA = (a.data()['totalScore'] as num?)?.toInt() ?? 0;
          final scoreB = (b.data()['totalScore'] as num?)?.toInt() ?? 0;
          if (scoreA != scoreB) {
            return scoreB.compareTo(scoreA);
          }

          final tsA =
              (a.data()['scoreTimestamp'] as num?)?.toInt() ??
              9223372036854775807;
          final tsB =
              (b.data()['scoreTimestamp'] as num?)?.toInt() ??
              9223372036854775807;
          if (tsA != tsB) {
            return tsA.compareTo(tsB);
          }

          final updatedA = a.data()['updatedAt'];
          final updatedB = b.data()['updatedAt'];
          if (updatedA is Timestamp && updatedB is Timestamp) {
            final cmp = updatedA.compareTo(updatedB);
            if (cmp != 0) {
              return cmp;
            }
          }

          return a.id.compareTo(b.id);
        });

      return docs
          .map((doc) => SciwordleLeaderboardEntry.fromFirestore(
                doc.data(),
                doc.id,
                isStreakActive: isStreakActive(
                  doc.data()['lastPlayedDate'] as String?,
                ),
              ))
          .take(50)
          .toList();
    } on FirebaseException catch (e) {
      throw Exception("Couldn't load the leaderboard: ${e.message}");
    } catch (_) {
      throw Exception("Something went wrong loading the leaderboard.");
    }
  }

  /// Fetches streaks for multiple users.
  Future<Map<String, int>> fetchStreaksForUsers(List<String> uids) async {
    final result = <String, int>{};
    try {
      final snapshot = await _db.collection(_scoresCol).get();
      for (final doc in snapshot.docs) {
        if (uids.contains(doc.id)) {
          final lastPlayed = doc.data()['lastPlayedDate'] as String?;
          if (isStreakActive(lastPlayed)) {
            result[doc.id] = (doc.data()['streak'] as num?)?.toInt() ?? 0;
          } else {
            result[doc.id] = 0;
          }
        }
      }
    } catch (_) {}
    return result;
  }

  // ─── Wordle letter-checking logic ─────────────────────────────────────────

  /// Checks a [guess] against the [answer] and returns letter-by-letter results.
  /// Both should be lowercase.
  SciwordleGuessResult checkGuess({
    required String guess,
    required String answer,
  }) {
    final guessChars = guess.split('');
    final answerChars = answer.split('');
    final statuses = List<LetterStatus>.filled(
      guess.length,
      LetterStatus.absent,
    );
    final remaining = List<String?>.from(answerChars);

    // Pass 1: greens
    for (int i = 0; i < guessChars.length; i++) {
      if (i < answerChars.length && guessChars[i] == answerChars[i]) {
        statuses[i] = LetterStatus.correct;
        remaining[i] = null;
      }
    }

    // Pass 2: yellows
    for (int i = 0; i < guessChars.length; i++) {
      if (statuses[i] == LetterStatus.correct) continue;
      final idx = remaining.indexOf(guessChars[i]);
      if (idx != -1) {
        statuses[i] = LetterStatus.present;
        remaining[idx] = null;
      }
    }

    return SciwordleGuessResult(
      letters: List.generate(
        guessChars.length,
        (i) => LetterResult(letter: guessChars[i], status: statuses[i]),
      ),
    );
  }
}

/// Represents saved in-progress guesses for the current day.
class SciwordleProgressData {
  const SciwordleProgressData({
    required this.guesses,
    required this.answer,
  });

  /// The list of guess words the user has submitted so far.
  final List<String> guesses;

  /// The answer word (to verify it matches today's question).
  final String answer;
}
