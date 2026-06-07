import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/delve_session_model.dart';
import '../models/delve_deck_model.dart';
import '../models/delve_word_model.dart';
import 'dart:math';

class SessionProvider extends ChangeNotifier {
  static const String _sessionKey = 'delve_current_session';

  Session? _currentSession;

  Session? get currentSession => _currentSession;

  SessionProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_sessionKey);
    if (jsonStr != null) {
      _currentSession = Session.fromJson(jsonDecode(jsonStr));
      
      // If the saved session is from a previous day and was completed, clear it
      if (_currentSession != null && _currentSession!.status == SessionStatus.completed) {
        final sessionDate = _currentSession!.date;
        final now = DateTime.now();
        final isToday = sessionDate.year == now.year &&
            sessionDate.month == now.month &&
            sessionDate.day == now.day;
        if (!isToday) {
          // Old completed session — clear it so a new day can begin
          _currentSession = null;
          await prefs.remove(_sessionKey);
        }
      }
      
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentSession != null) {
      await prefs.setString(_sessionKey, jsonEncode(_currentSession!.toJson()));
    } else {
      await prefs.remove(_sessionKey);
    }
  }

  /// Check if today's session is already completed.
  bool get isSessionCompletedToday {
    if (_currentSession == null) return false;
    if (_currentSession!.status != SessionStatus.completed) return false;
    final sessionDate = _currentSession!.date;
    final now = DateTime.now();
    return sessionDate.year == now.year &&
        sessionDate.month == now.month &&
        sessionDate.day == now.day;
  }

  /// Build and start a session for the given deck and day.
  void startSession(Deck deck, String sessionId, List<String> archiveWordIds) {
    // Determine which words are for today's review.
    // Days 1-12: cycles through set1, set2, set3 for the 5 swipe cards
    List<String> todaySwipeWords = [];
    if (deck.currentDay % 3 == 1) {
      todaySwipeWords = deck.set1WordIds;
    } else if (deck.currentDay % 3 == 2) {
      todaySwipeWords = deck.set2WordIds;
    } else if (deck.currentDay % 3 == 0) {
      todaySwipeWords = deck.set3WordIds;
    }

    List<SessionCard> cards = [];
    
    if (deck.currentDay == 13) {
      // Test day: All 15 words as active AI-validated cards
      cards = deck.allWordIds
          .map((id) => SessionCard(wordId: id, type: CardType.active))
          .toList();
      cards.shuffle(Random());
    } else {
      // Normal day: 5 swipe cards + 2 active cards from the archive
      
      // 5 swipe cards first
      final swipeCards = todaySwipeWords
          .map((id) => SessionCard(wordId: id, type: CardType.swipe))
          .toList();
          
      List<SessionCard> activeCards = [];
      if (archiveWordIds.isEmpty) {
        // Create one dummy card to trigger the "no words in archive" UI
        activeCards.add(SessionCard(wordId: 'empty_archive', type: CardType.active));
      } else {
        // Fetch randomly from archive
        final archiveCopy = List<String>.from(archiveWordIds)..shuffle(Random());
        final selectedArchive = archiveCopy.take(2).toList();
        activeCards = selectedArchive
            .map((id) => SessionCard(wordId: id, type: CardType.active))
            .toList();
      }
      
      // Swipe cards come first, then active cards (per spec flow)
      cards.addAll(swipeCards);
      cards.addAll(activeCards);
    }

    _currentSession = Session(
      id: sessionId,
      deckId: deck.id,
      day: deck.currentDay,
      date: DateTime.now(),
      cards: cards,
      status: SessionStatus.inProgress,
    );
    
    notifyListeners();
    _saveData();
  }
  
  /// Complete the current card with pass/fail result.
  void completeCurrentCard(ActiveCardResult result) {
    if (_currentSession == null) return;
    
    final index = _currentSession!.cards.indexWhere((c) => !c.isCompleted);
    if (index != -1) {
      _currentSession!.cards[index].isCompleted = true;
      _currentSession!.cards[index].result = result;
      
      if (_currentSession!.isFinished) {
        _currentSession!.status = SessionStatus.completed;
      }
      notifyListeners();
      _saveData();
    }
  }

  /// Get the results summary for a completed session (used for Test Day).
  Map<String, List<String>> getSessionResults() {
    if (_currentSession == null) return {'passed': [], 'failed': []};
    
    final passed = _currentSession!.cards
        .where((c) => c.result == ActiveCardResult.passed)
        .map((c) => c.wordId)
        .toList();
    final failed = _currentSession!.cards
        .where((c) => c.result == ActiveCardResult.failed)
        .map((c) => c.wordId)
        .toList();
    
    return {'passed': passed, 'failed': failed};
  }

  /// Clear the current session (after day is processed).
  void endSession() {
    _currentSession = null;
    notifyListeners();
    _saveData();
  }
}
