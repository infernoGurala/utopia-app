import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/focus_models.dart';
import 'focus_database_service.dart';
import 'notification_service.dart';

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

  FocusSupabaseService._() {
    _setupConnectivityListener();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('Focus Supabase: Auth state change detected (User logged in). Re-initializing and syncing...');
        _initialized = false;
        initialize().then((success) {
          _syncPendingData().then((_) => syncDownAllData());
        });
      }
    });
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results is List
          ? results.any((r) => r != ConnectivityResult.none)
          : results != ConnectivityResult.none;
      if (hasConnection) {
        debugPrint('Focus Supabase: Internet connectivity detected. Syncing pending data...');
        initialize().then((success) {
          _syncPendingData().then((_) => syncDownAllData());
        });
      }
    });
  }

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
        debugPrint('Focus Supabase: Firestore config [supabase-focus-1] not found. Falling back to primary instance...');
        try {
          _client = supa.Supabase.instance.client;
          _initialized = true;
          _initializing = false;
          debugPrint('Focus Supabase: Initialized successfully using Primary Fallback client!');
          _syncPendingData().then((_) => syncDownAllData());
          return true;
        } catch (fallbackError) {
          debugPrint('Primary Supabase fallback failed: $fallbackError');
        }
        _initializing = false;
        return false;
      }

      final data = doc.data()!;
      final url = data['url'] as String?;
      final anonKey = data['anon_key'] as String?;

      if (url == null || anonKey == null) {
        debugPrint('Focus Supabase config missing url or anon_key. Falling back to primary instance...');
        try {
          _client = supa.Supabase.instance.client;
          _initialized = true;
          _initializing = false;
          debugPrint('Focus Supabase: Initialized successfully using Primary Fallback client!');
          _syncPendingData().then((_) => syncDownAllData());
          return true;
        } catch (fallbackError) {
          debugPrint('Primary Supabase fallback failed: $fallbackError');
        }
        _initializing = false;
        return false;
      }

      _client = supa.SupabaseClient(url, anonKey);
      _initialized = true;
      _initializing = false;
      debugPrint('Focus Supabase: Initialized successfully with dedicated project URL: $url');

      // Background sync of pending data
      _syncPendingData().then((_) => syncDownAllData());

      return true;
    } catch (e) {
      debugPrint('Failed to initialize Focus Supabase, trying primary instance: $e');
      try {
        _client = supa.Supabase.instance.client;
        _initialized = true;
        _initializing = false;
        _syncPendingData().then((_) => syncDownAllData());
        return true;
      } catch (fallbackError) {
        debugPrint('Primary Supabase fallback failed: $fallbackError');
      }
      _initializing = false;
      return false;
    }
  }

  // ──────────────────────────── Daily Notes ────────────────────────────

  /// Save a note: write to SQLite first (optimistic), then sync to Supabase
  Future<FocusNote> saveNote(FocusNote note) async {
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
        debugPrint('Focus Supabase: Successfully synced note for ${noteWithId.date} online!');
      } catch (e) {
        if (e is supa.PostgrestException) {
          debugPrint('Focus Supabase note sync failed with PostgrestException: [${e.code}] ${e.message} - Details: ${e.details} - Hint: ${e.hint}');
        } else {
          debugPrint('Focus Supabase note sync failed: $e');
        }
        rethrow;
      }
    }
    return noteWithId;
  }

  /// Get local note from SQLite directly without any network calls
  Future<FocusNote?> getLocalNote(String date) async {
    final userId = _userId;
    if (userId.isEmpty) return null;
    return _db.getNote(userId, date);
  }

  /// Get local user habits from SQLite directly without any network calls
  Future<FocusUserHabits?> getLocalUserHabits() async {
    final userId = _userId;
    if (userId.isEmpty) return null;
    return _db.getUserHabits(userId);
  }

  /// Get local note dates from SQLite directly without any network calls
  Future<Set<String>> getLocalNoteDates(String startDate, String endDate) async {
    final userId = _userId;
    if (userId.isEmpty) return {};
    return _db.getNoteDates(userId, startDate, endDate);
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

  /// Get dates that have notes. Syncs range from Supabase in the background to update SQLite.
  Future<Set<String>> getNoteDates(String startDate, String endDate) async {
    final userId = _userId;
    if (userId.isEmpty) return {};

    // Pull notes from Supabase for this date range to sync the local cache
    if (_initialized && _client != null) {
      try {
        final response = await _client!
            .from('daily_notes')
            .select()
            .eq('user_id', userId)
            .gte('date', startDate)
            .lte('date', endDate);

        if (response != null) {
          final List<dynamic> rows = response;
          for (final row in rows) {
            final remoteNote = FocusNote.fromMap(row as Map<String, dynamic>).copyWith(syncStatus: 'synced');
            final localNote = await _db.getNote(userId, remoteNote.date);
            if (localNote == null ||
                (remoteNote.updatedAt != null &&
                    localNote.updatedAt != null &&
                    remoteNote.updatedAt!.isAfter(localNote.updatedAt!))) {
              await _db.saveNote(remoteNote);
            }
          }
        }
      } catch (e) {
        debugPrint('Focus Supabase getNoteDates sync failed: $e');
      }
    }

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

    // Schedule local timezone-based notification
    await NotificationService.scheduleFocusReminder(reminderWithId);

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

    // Cancel any scheduled local notifications
    await NotificationService.cancelFocusReminder(reminderId);

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
          debugPrint('Focus Supabase: Successfully synced pending note for ${note.date} online!');
        } catch (e) {
          if (e is supa.PostgrestException) {
            debugPrint('Focus Supabase pending note sync for ${note.date} failed with PostgrestException: [${e.code}] ${e.message} - Details: ${e.details} - Hint: ${e.hint}');
          } else {
            debugPrint('Focus Supabase: Pending note sync for ${note.date} failed: $e');
          }
        }
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
          debugPrint('Focus Supabase: Successfully synced pending completions for ${parts[1]} online!');
        } catch (e) {
          if (e is supa.PostgrestException) {
            debugPrint('Focus Supabase pending completions sync for ${parts[1]} failed with PostgrestException: [${e.code}] ${e.message} - Details: ${e.details} - Hint: ${e.hint}');
          } else {
            debugPrint('Focus Supabase: Pending completions sync for ${parts[1]} failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Focus sync failed: $e');
    }
  }

  Future<void> syncDownAllData() async {
    final userId = _userId;
    if (userId.isEmpty || !_initialized || _client == null) return;

    try {
      debugPrint('Focus Supabase: Starting full download sync of user data...');

      // 1. Fetch and sync focus_user_habits
      final habitsResponse = await _client!
          .from('focus_user_habits')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (habitsResponse != null) {
        final remoteHabits = FocusUserHabits.fromMap(habitsResponse).copyWith(syncStatus: 'synced');
        await _db.saveUserHabits(remoteHabits);
      }

      // 2. Fetch and sync daily_notes
      final notesResponse = await _client!
          .from('daily_notes')
          .select()
          .eq('user_id', userId);
      if (notesResponse != null) {
        final List<dynamic> noteRows = notesResponse;
        for (final row in noteRows) {
          final remoteNote = FocusNote.fromMap(row as Map<String, dynamic>).copyWith(syncStatus: 'synced');
          await _db.saveNote(remoteNote);

          // Derived completions for this note
          final List<HabitCompletion> completions = [];
          remoteNote.habitsState.forEach((habitName, completed) {
            completions.add(HabitCompletion(
              userId: remoteNote.userId,
              date: remoteNote.date,
              taskName: habitName.toLowerCase().trim(),
              completed: completed,
              completionCount: completed ? 1 : 0,
              syncStatus: 'synced',
            ));
          });
          for (final task in remoteNote.tasks) {
            final label = (task['label'] as String?)?.toLowerCase().trim() ?? '';
            if (label.isEmpty) continue;
            final completed = task['completed'] == true;
            completions.add(HabitCompletion(
              userId: remoteNote.userId,
              date: remoteNote.date,
              taskName: label,
              completed: completed,
              completionCount: completed ? 1 : 0,
              syncStatus: 'synced',
            ));
          }
          await _db.saveCompletions(remoteNote.userId, remoteNote.date, completions);
        }
      }

      // 3. Fetch and sync reminders
      final remindersResponse = await _client!
          .from('reminders')
          .select()
          .eq('user_id', userId);
      if (remindersResponse != null) {
        final List<dynamic> reminderRows = remindersResponse;
        for (final row in reminderRows) {
          final remoteReminder = FocusReminder.fromMap(row as Map<String, dynamic>).copyWith(syncStatus: 'synced');
          await _db.saveReminder(remoteReminder);
          // Reschedule local timezone-based notification
          await NotificationService.scheduleFocusReminder(remoteReminder);
        }
      }

      debugPrint('Focus Supabase: Finished full download sync successfully!');
    } catch (e) {
      debugPrint('Focus Supabase full download sync failed: $e');
    }
  }

  // ──────────────────────────── Helpers ────────────────────────────

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

}
