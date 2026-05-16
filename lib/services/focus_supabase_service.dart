import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:uuid/uuid.dart';
import '../models/focus_models.dart';
import 'focus_database_service.dart';

/// Manages the dedicated Focus Supabase project.
///
/// This is a separate Supabase instance from the main UTOPIA one.
/// Credentials are fetched from Firestore at `config/supabase-focus-1`.
class FocusSupabaseService {
  static FocusSupabaseService? _instance;
  supa.SupabaseClient? _client;
  bool _initialized = false;
  bool _initializing = false;
  final _db = FocusDatabaseService();
  static const _uuid = Uuid();

  FocusSupabaseService._();

  factory FocusSupabaseService() {
    _instance ??= FocusSupabaseService._();
    return _instance!;
  }

  bool get isInitialized => _initialized;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Initialize the Focus Supabase client from Firestore config
  Future<bool> initialize() async {
    if (_initialized) return true;
    if (_initializing) return false;
    _initializing = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('supabase-focus-1')
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('Focus Supabase config not found');
        _initializing = false;
        return false;
      }

      final data = doc.data()!;
      final url = data['url'] as String?;
      final anonKey = data['anon_key'] as String?;

      if (url == null || anonKey == null) {
        debugPrint('Focus Supabase config missing url or anon_key');
        _initializing = false;
        return false;
      }

      _client = supa.SupabaseClient(url, anonKey);
      _initialized = true;
      _initializing = false;

      // Background sync of pending data
      _syncPendingData();

      return true;
    } catch (e) {
      debugPrint('Failed to initialize Focus Supabase: $e');
      _initializing = false;
      return false;
    }
  }

  // ──────────────────────────── Daily Notes ────────────────────────────

  /// Save a note: write to SQLite first (optimistic), then sync to Supabase
  Future<void> saveNote(FocusNote note) async {
    final now = DateTime.now();
    final noteWithId = note.copyWith(
      id: note.id ?? _uuid.v4(),
      syncStatus: 'pending',
      updatedAt: now,
      createdAt: note.createdAt ?? now,
    );

    // 1. Save locally
    await _db.saveNote(noteWithId);

    // 2. Extract task completions and save locally
    final List<HabitCompletion> completions = [];
    
    // Habits
    noteWithId.habitsState.forEach((habitName, completed) {
      completions.add(HabitCompletion(
        userId: noteWithId.userId,
        date: noteWithId.date,
        taskName: habitName.toLowerCase().trim(),
        completed: completed,
        completionCount: completed ? 1 : 0,
        syncStatus: 'pending',
      ));
    });

    // Tasks
    for (final task in noteWithId.tasks) {
      final label = (task['label'] as String?)?.toLowerCase().trim() ?? '';
      if (label.isEmpty) continue;
      final completed = task['completed'] == true;
      completions.add(HabitCompletion(
        userId: noteWithId.userId,
        date: noteWithId.date,
        taskName: label,
        completed: completed,
        completionCount: completed ? 1 : 0,
        syncStatus: 'pending',
      ));
    }

    await _db.saveCompletions(noteWithId.userId, noteWithId.date, completions);

    // 3. Sync to Supabase in background
    if (_initialized && _client != null) {
      try {
        await _client!.from('daily_notes').upsert(
          noteWithId.toSupabaseMap(),
          onConflict: 'user_id,date',
        );
        await _db.markNoteSynced(noteWithId.userId, noteWithId.date);

        // Sync completions
        await _client!.from('habit_completions').delete().match({
          'user_id': noteWithId.userId,
          'date': noteWithId.date,
        });
        if (completions.isNotEmpty) {
          await _client!.from('habit_completions').insert(
            completions.map((c) => c.toSupabaseMap()).toList(),
          );
        }
        await _db.markCompletionsSynced(noteWithId.userId, noteWithId.date);
      } catch (e) {
        debugPrint('Focus Supabase note sync failed: $e');
        // stays pending, will retry later
      }
    }
  }

  /// Load a note for a specific date. SQLite first, then Supabase refresh.
  Future<FocusNote?> loadNote(String date) async {
    final userId = _userId;
    if (userId.isEmpty) return null;

    // 1. Try local
    final localNote = await _db.getNote(userId, date);

    // 2. Try Supabase in background
    if (_initialized && _client != null) {
      try {
        final response = await _client!
            .from('daily_notes')
            .select()
            .eq('user_id', userId)
            .eq('date', date)
            .maybeSingle();

        if (response != null) {
          final remoteNote = FocusNote.fromMap(response).copyWith(syncStatus: 'synced');

          // If remote is newer or local doesn't exist, use remote
          if (localNote == null ||
              (remoteNote.updatedAt != null &&
                  localNote.updatedAt != null &&
                  remoteNote.updatedAt!.isAfter(localNote.updatedAt!))) {
            await _db.saveNote(remoteNote);
            return remoteNote;
          }
        }
      } catch (e) {
        debugPrint('Focus Supabase note load failed: $e');
      }
    }

    return localNote;
  }

  /// Delete a note
  Future<void> deleteNote(String date) async {
    final userId = _userId;
    if (userId.isEmpty) return;

    await _db.deleteNote(userId, date);

    if (_initialized && _client != null) {
      try {
        await _client!.from('daily_notes').delete().match({
          'user_id': userId,
          'date': date,
        });
        await _client!.from('habit_completions').delete().match({
          'user_id': userId,
          'date': date,
        });
      } catch (e) {
        debugPrint('Focus Supabase note delete failed: $e');
      }
    }
  }

  /// Get dates that have notes
  Future<Set<String>> getNoteDates(String startDate, String endDate) async {
    final userId = _userId;
    if (userId.isEmpty) return {};
    return _db.getNoteDates(userId, startDate, endDate);
  }

  // ──────────────────────────── User Habits ────────────────────────────

  Future<FocusUserHabits?> getUserHabits() async {
    final userId = _userId;
    if (userId.isEmpty) return null;

    final localConfig = await _db.getUserHabits(userId);

    if (_initialized && _client != null) {
      try {
        final response = await _client!
            .from('focus_user_habits')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null) {
          final remoteConfig = FocusUserHabits.fromMap(response).copyWith(syncStatus: 'synced');
          await _db.saveUserHabits(remoteConfig);
          return remoteConfig;
        }
      } catch (e) {
        debugPrint('Focus Supabase user habits load failed: $e');
      }
    }

    return localConfig;
  }

  Future<void> saveUserHabits(FocusUserHabits habits) async {
    final userId = _userId;
    if (userId.isEmpty) return;

    final config = habits.copyWith(userId: userId, syncStatus: 'pending');
    await _db.saveUserHabits(config);

    if (_initialized && _client != null) {
      try {
        await _client!.from('focus_user_habits').upsert(config.toSupabaseMap(), onConflict: 'user_id');
        await _db.markUserHabitsSynced(userId);
      } catch (e) {
        debugPrint('Focus Supabase user habits sync failed: $e');
      }
    }
  }

  // ──────────────────────────── Heatmap ────────────────────────────

  Future<List<HabitCompletion>> getCompletionsForTask(
    String taskName, {
    int days = 365,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) return [];

    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final startStr = _dateStr(start);
    final endStr = _dateStr(now);

    return _db.getCompletionsForTask(userId, taskName, startStr, endStr);
  }

  Future<List<Map<String, dynamic>>> getAllTrackedTasks() async {
    final userId = _userId;
    if (userId.isEmpty) return [];
    return _db.getAllTrackedTasks(userId);
  }

  Future<int> getCurrentStreak(String taskName) async {
    final userId = _userId;
    if (userId.isEmpty) return 0;
    return _db.getCurrentStreak(userId, taskName);
  }

  Future<int> getLongestStreak(String taskName) async {
    final userId = _userId;
    if (userId.isEmpty) return 0;
    return _db.getLongestStreak(userId, taskName);
  }

  Future<Map<String, dynamic>?> getBestActiveStreak() async {
    final userId = _userId;
    if (userId.isEmpty) return null;
    return _db.getBestActiveStreak(userId);
  }

  // ──────────────────────────── Reminders ────────────────────────────

  Future<List<FocusReminder>> getReminders() async {
    final userId = _userId;
    if (userId.isEmpty) return [];
    return _db.getReminders(userId);
  }

  Future<void> saveReminder(FocusReminder reminder) async {
    final reminderWithId = reminder.copyWith(
      id: reminder.id ?? _uuid.v4(),
      syncStatus: 'pending',
    );

    await _db.saveReminder(reminderWithId);

    if (_initialized && _client != null) {
      try {
        await _client!.from('reminders').upsert(
          {
            ...reminderWithId.toSupabaseMap(),
            'id': reminderWithId.id,
          },
          onConflict: 'id',
        );
        await _db.markReminderSynced(reminderWithId.id!);
      } catch (e) {
        debugPrint('Focus Supabase reminder sync failed: $e');
      }
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    await _db.deleteReminder(reminderId);

    if (_initialized && _client != null) {
      try {
        await _client!.from('reminders').delete().eq('id', reminderId);
      } catch (e) {
        debugPrint('Focus Supabase reminder delete failed: $e');
      }
    }
  }

  // ──────────────────────────── Sync ────────────────────────────

  Future<void> _syncPendingData() async {
    if (!_initialized || _client == null) return;

    try {
      // Sync pending user habits
      final pendingHabits = await _db.getPendingUserHabits();
      for (final h in pendingHabits) {
        try {
          await _client!.from('focus_user_habits').upsert(
            h.toSupabaseMap(),
            onConflict: 'user_id',
          );
          await _db.markUserHabitsSynced(h.userId);
        } catch (_) {}
      }

      // Sync pending notes
      final pendingNotes = await _db.getPendingNotes();
      for (final note in pendingNotes) {
        try {
          await _client!.from('daily_notes').upsert(
            note.toSupabaseMap(),
            onConflict: 'user_id,date',
          );
          await _db.markNoteSynced(note.userId, note.date);
        } catch (_) {}
      }

      // Sync pending completions
      final pendingCompletions = await _db.getPendingCompletions();
      final grouped = <String, List<HabitCompletion>>{};
      for (final c in pendingCompletions) {
        final key = '${c.userId}|${c.date}';
        grouped.putIfAbsent(key, () => []).add(c);
      }
      for (final entry in grouped.entries) {
        final parts = entry.key.split('|');
        try {
          await _client!.from('habit_completions').delete().match({
            'user_id': parts[0],
            'date': parts[1],
          });
          await _client!.from('habit_completions').insert(
            entry.value.map((c) => c.toSupabaseMap()).toList(),
          );
          await _db.markCompletionsSynced(parts[0], parts[1]);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Focus sync failed: $e');
    }
  }

  // ──────────────────────────── Helpers ────────────────────────────

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

}
