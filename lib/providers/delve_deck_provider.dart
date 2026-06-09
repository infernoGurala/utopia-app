import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/delve_deck_model.dart';
import '../models/delve_word_model.dart';
import '../services/delve_supabase_service.dart';
import '../services/notification_service.dart';

class DeckProvider extends ChangeNotifier {
  static const String _activeDeckKey = 'delve_active_deck';
  static const String _completedDecksKey = 'delve_completed_decks';

  final _supabaseService = DelveSupabaseService();
  Deck? _activeDeck;
  int _completedDecksCount = 0;
  String? _uid;

  Deck? get activeDeck => _activeDeck;
  int get completedDecksCount => _completedDecksCount;

  DeckProvider() {
    _loadLocalData();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Called after login to sync with cloud.
  Future<void> initForUser(String uid) async {
    _uid = uid;
    await _loadFromCloud(uid);
  }

  void clearUserData() {
    _uid = null;
    _activeDeck = null;
    _completedDecksCount = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final deckString = prefs.getString(_activeDeckKey);
    if (deckString != null) {
      _activeDeck = Deck.fromJson(jsonDecode(deckString));
    }
    
    _completedDecksCount = prefs.getInt(_completedDecksKey) ?? 0;
    
    // Check missed days on local load
    checkMissedDayAndSync();
    _syncDelveNotifications();
    notifyListeners();
  }

  Future<void> _loadFromCloud(String uid) async {
    try {
      final cloudDeck = await _supabaseService.getActiveDeck(uid);
      if (cloudDeck != null) {
        _activeDeck = cloudDeck;
      }

      final profile = await _supabaseService.getProfile(uid);
      if (profile != null) {
        _completedDecksCount = profile['total_decks_completed'] ?? 0;
      }

      // Check missed days after cloud load
      checkMissedDayAndSync();
      _syncDelveNotifications();
      notifyListeners();
      _saveLocalCache();
    } catch (e) {
      debugPrint('Failed to load deck from Supabase: $e');
    }
  }

  Future<void> _saveLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activeDeck != null) {
      await prefs.setString(_activeDeckKey, jsonEncode(_activeDeck!.toJson()));
    } else {
      await prefs.remove(_activeDeckKey);
    }
    await prefs.setInt(_completedDecksKey, _completedDecksCount);
  }

  // ---------------------------------------------------------------------------
  // Missed Day Detection
  // ---------------------------------------------------------------------------

  void checkMissedDayAndSync() {
    if (_activeDeck == null) return;
    if (_activeDeck!.status == DeckStatus.completed) return;

    bool changed = false;
    if (_activeDeck!.hasMissedDay) {
      debugPrint('Missed day detected. Resetting deck to Day 1.');
      _activeDeck = _activeDeck!.copyWith(
        currentDay: 1,
        status: DeckStatus.active,
      );
      changed = true;
    } else if (_activeDeck!.isNewDayReady && _activeDeck!.currentDay < 13) {
      final nextDay = _activeDeck!.currentDay + 1;
      _activeDeck = _activeDeck!.copyWith(
        currentDay: nextDay,
        status: nextDay == 13 ? DeckStatus.testDay : DeckStatus.active,
      );
      changed = true;
    }

    if (changed) {
      _syncDeckToCloud();
      _saveLocalCache();
      _syncDelveNotifications();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Deck Creation
  // ---------------------------------------------------------------------------

  void createDeckFromWords(List<Word> words) {
    if (words.length != 15) return;
    
    _activeDeck = Deck(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      currentDay: 1,
      status: DeckStatus.active,
      set1WordIds: words.sublist(0, 5).map((w) => w.id).toList(),
      set2WordIds: words.sublist(5, 10).map((w) => w.id).toList(),
      set3WordIds: words.sublist(10, 15).map((w) => w.id).toList(),
    );
    notifyListeners();
    _saveLocalCache();
    _syncDeckToCloud();
    NotificationService.scheduleDelveReminders();
  }

  // ---------------------------------------------------------------------------
  // Session Completion
  // ---------------------------------------------------------------------------

  void markSessionCompleted() {
    if (_activeDeck == null) return;

    _activeDeck = _activeDeck!.copyWith(
      lastSessionDate: DateTime.now(),
    );
    notifyListeners();
    _saveLocalCache();
    _syncDeckToCloud();
    NotificationService.cancelDelveReminders();
  }

  void completeDeck() {
    if (_activeDeck == null) return;
    _completedDecksCount++;
    
    // Delete deck from cloud
    if (_uid != null) {
      _supabaseService.deleteActiveDeck(_uid!).catchError((e) {
        debugPrint('Failed to delete deck from Supabase: $e');
      });
      // Update profile stats
      final wordsLearned = _activeDeck!.allWordIds.length;
      _supabaseService.incrementDeckStats(_uid!, wordsLearned).catchError((e) {
        debugPrint('Failed to increment deck stats: $e');
      });
    }
    
    _activeDeck = null;
    notifyListeners();
    _saveLocalCache();
    NotificationService.cancelDelveReminders();
  }

  void resetDeckToDayOne() {
    if (_activeDeck == null) return;
    _activeDeck = Deck(
      id: _activeDeck!.id,
      startedAt: DateTime.now(),
      currentDay: 1,
      status: DeckStatus.active,
      set1WordIds: _activeDeck!.set1WordIds,
      set2WordIds: _activeDeck!.set2WordIds,
      set3WordIds: _activeDeck!.set3WordIds,
      lastSessionDate: null,
    );
    notifyListeners();
    _saveLocalCache();
    _syncDeckToCloud();
  }

  void abandonDeck() {
    if (_activeDeck == null) return;
    
    // Delete deck from cloud
    if (_uid != null) {
      _supabaseService.deleteActiveDeck(_uid!).catchError((e) {
        debugPrint('Failed to delete deck from Supabase: $e');
      });
    }
    
    _activeDeck = null;
    notifyListeners();
    _saveLocalCache();
    NotificationService.cancelDelveReminders();
  }

  void resetTodaysSession() {
    if (_activeDeck == null) return;
    _activeDeck = _activeDeck!.copyWith(
      lastSessionDate: null,
    );
    notifyListeners();
    _saveLocalCache();
    _syncDeckToCloud();
  }

  // ---------------------------------------------------------------------------
  // Cloud Sync Helper
  // ---------------------------------------------------------------------------

  void _syncDeckToCloud() {
    if (_uid == null || _activeDeck == null) return;
    _supabaseService.saveActiveDeck(_uid!, _activeDeck!).catchError((e) {
      debugPrint('Failed to sync deck to Supabase: $e');
    });
  }

  /// Schedule or cancel Delve notifications based on current deck state.
  void _syncDelveNotifications() {
    if (_activeDeck == null || _activeDeck!.status == DeckStatus.completed) {
      NotificationService.cancelDelveReminders();
      return;
    }
    if (_activeDeck!.isSessionCompletedToday) {
      NotificationService.cancelDelveReminders();
    } else {
      NotificationService.scheduleDelveReminders();
    }
  }
}
