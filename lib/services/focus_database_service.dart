import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/focus_models.dart';

/// Local SQLite cache for Focus feature data.
///
/// Mirrors the Supabase schema with an additional `sync_status` column
/// for offline-first support.
class FocusDatabaseService {
  static FocusDatabaseService? _instance;
  static Database? _database;

  FocusDatabaseService._();

  factory FocusDatabaseService() {
    _instance ??= FocusDatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'focus_data.db');
    return openDatabase(
      path,
      version: 6,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS daily_notes');
          await db.execute('''
            CREATE TABLE daily_notes (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              date TEXT NOT NULL,
              habits_state TEXT NOT NULL DEFAULT '{}',
              tasks TEXT NOT NULL DEFAULT '[]',
              journal TEXT NOT NULL DEFAULT '',
              sync_status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE(user_id, date)
            )
          ''');
          await db.execute('CREATE INDEX idx_notes_user_date ON daily_notes(user_id, date)');
          await db.execute('''
            CREATE TABLE focus_user_habits (
              user_id TEXT PRIMARY KEY,
              habits TEXT NOT NULL DEFAULT '[]',
              sync_status TEXT NOT NULL DEFAULT 'pending'
            )
          ''');
        }
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE daily_notes ADD COLUMN journal TEXT NOT NULL DEFAULT ''");
          } catch (_) {}
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE habits (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              type TEXT NOT NULL,
              target_value REAL NOT NULL DEFAULT 1.0,
              unit TEXT,
              frequency_type TEXT NOT NULL,
              frequency_value INTEGER NOT NULL DEFAULT 1,
              days_of_week TEXT,
              reminder_time TEXT,
              color TEXT NOT NULL DEFAULT '#08BB68',
              is_archived INTEGER NOT NULL DEFAULT 0,
              sync_status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE habit_records (
              id TEXT PRIMARY KEY,
              habit_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              date TEXT NOT NULL,
              value REAL NOT NULL DEFAULT 0.0,
              target_value REAL NOT NULL DEFAULT 1.0,
              completed INTEGER NOT NULL DEFAULT 0,
              note TEXT,
              sync_status TEXT NOT NULL DEFAULT 'pending',
              updated_at TEXT NOT NULL,
              UNIQUE(habit_id, date)
            )
          ''');
          await db.execute('CREATE INDEX idx_habit_records_date ON habit_records(user_id, date)');
          await db.execute('CREATE INDEX idx_habit_records_habit_date ON habit_records(habit_id, date)');

          // Data migration from focus_user_habits and habit_completions
          const uuid = Uuid();
          try {
            final userHabitsRows = await db.query('focus_user_habits');
            for (final row in userHabitsRows) {
              final userId = row['user_id'] as String;
              final habitsJson = row['habits'] as String? ?? '[]';
              List<dynamic> habitsList = [];
              try {
                habitsList = jsonDecode(habitsJson) as List;
              } catch (_) {}

              for (final habitNameDyn in habitsList) {
                final habitName = habitNameDyn.toString().trim();
                if (habitName.isEmpty) continue;

                final habitId = uuid.v4();
                final nowIso = DateTime.now().toIso8601String();

                // Insert into new habits table
                await db.insert('habits', {
                  'id': habitId,
                  'user_id': userId,
                  'name': habitName,
                  'description': 'Daily habit',
                  'type': 'binary',
                  'target_value': 1.0,
                  'unit': null,
                  'frequency_type': 'daily',
                  'frequency_value': 1,
                  'days_of_week': null,
                  'reminder_time': null,
                  'color': '#08BB68',
                  'is_archived': 0,
                  'sync_status': 'pending',
                  'created_at': nowIso,
                  'updated_at': nowIso,
                });

                // Retrieve historical checks for this task_name and user_id
                final completions = await db.query(
                  'habit_completions',
                  where: 'user_id = ? AND task_name = ?',
                  whereArgs: [userId, habitName.toLowerCase().trim()],
                );

                for (final comp in completions) {
                  final date = comp['date'] as String;
                  final completed = comp['completed'] as int? ?? 0;
                  
                  await db.insert('habit_records', {
                    'id': uuid.v4(),
                    'habit_id': habitId,
                    'user_id': userId,
                    'date': date,
                    'value': completed == 1 ? 1.0 : 0.0,
                    'target_value': 1.0,
                    'completed': completed,
                    'note': null,
                    'sync_status': 'pending',
                    'updated_at': nowIso,
                  });
                }
              }
            }
          } catch (e) {
            print('Migration to version 4 error/warning: $e');
          }
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE reminders ADD COLUMN gcal_event_id TEXT');
          } catch (e) {
            print('Migration to version 5 error/warning: $e');
          }
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE reminders ADD COLUMN description TEXT');
            await db.execute('ALTER TABLE reminders ADD COLUMN habit_id TEXT');
          } catch (e) {
            print('Migration to version 6 error/warning: $e');
          }
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE daily_notes (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            habits_state TEXT NOT NULL DEFAULT '{}',
            tasks TEXT NOT NULL DEFAULT '[]',
            journal TEXT NOT NULL DEFAULT '',
            sync_status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(user_id, date)
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_notes_user_date ON daily_notes(user_id, date)
        ''');

        await db.execute('''
          CREATE TABLE focus_user_habits (
            user_id TEXT PRIMARY KEY,
            habits TEXT NOT NULL DEFAULT '[]',
            sync_status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');

        await db.execute('''
          CREATE TABLE habit_completions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            task_name TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            completion_count INTEGER NOT NULL DEFAULT 1,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            UNIQUE(user_id, date, task_name)
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_hc_user_task_date ON habit_completions(user_id, task_name, date)
        ''');
        await db.execute('''
          CREATE INDEX idx_hc_user_date ON habit_completions(user_id, date)
        ''');

        await db.execute('''
          CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            label TEXT NOT NULL,
            description TEXT,
            habit_id TEXT,
            type TEXT NOT NULL,
            reminder_time TEXT NOT NULL,
            remind_date TEXT,
            weekdays TEXT,
            month_day INTEGER,
            active_months TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            gcal_event_id TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_reminders_user ON reminders(user_id, is_active)
        ''');

        // User template storage
        await db.execute('''
          CREATE TABLE focus_templates (
            user_id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Create habits and habit_records tables directly for version 4 fresh installations
        await db.execute('''
          CREATE TABLE habits (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            type TEXT NOT NULL,
            target_value REAL NOT NULL DEFAULT 1.0,
            unit TEXT,
            frequency_type TEXT NOT NULL,
            frequency_value INTEGER NOT NULL DEFAULT 1,
            days_of_week TEXT,
            reminder_time TEXT,
            color TEXT NOT NULL DEFAULT '#08BB68',
            is_archived INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE habit_records (
            id TEXT PRIMARY KEY,
            habit_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            value REAL NOT NULL DEFAULT 0.0,
            target_value REAL NOT NULL DEFAULT 1.0,
            completed INTEGER NOT NULL DEFAULT 0,
            note TEXT,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            updated_at TEXT NOT NULL,
            UNIQUE(habit_id, date)
          )
        ''');
        await db.execute('CREATE INDEX idx_habit_records_date ON habit_records(user_id, date)');
        await db.execute('CREATE INDEX idx_habit_records_habit_date ON habit_records(habit_id, date)');
      },
    );
  }

  // ──────────────────────────── User Habits Config ────────────────────────────

  Future<FocusUserHabits?> getUserHabits(String userId) async {
    final db = await database;
    final results = await db.query(
      'focus_user_habits',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FocusUserHabits.fromMap(results.first);
  }

  Future<void> saveUserHabits(FocusUserHabits habits) async {
    final db = await database;
    await db.insert(
      'focus_user_habits',
      habits.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ──────────────────────────── Daily Notes ────────────────────────────

  Future<FocusNote?> getNote(String userId, String date) async {
    final db = await database;
    final results = await db.query(
      'daily_notes',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FocusNote.fromMap(results.first);
  }

  Future<void> saveNote(FocusNote note) async {
    final db = await database;
    await db.insert(
      'daily_notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(String userId, String date) async {
    final db = await database;
    await db.delete(
      'daily_notes',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
    // Also delete associated completions
    await db.delete(
      'habit_completions',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
  }

  /// Returns dates that have notes for the given user and date range
  Future<Set<String>> getNoteDates(
    String userId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final results = await db.query(
      'daily_notes',
      columns: ['date'],
      where: 'user_id = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startDate, endDate],
    );
    return results.map((r) => r['date'] as String).toSet();
  }

  // ──────────────────────────── Habit Completions ────────────────────────────

  Future<void> saveCompletions(
    String userId,
    String date,
    List<HabitCompletion> completions,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete existing for this user+date
      await txn.delete(
        'habit_completions',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
      );
      // Insert fresh
      for (final c in completions) {
        await txn.insert('habit_completions', c.toMap());
      }
    });
  }

  Future<List<HabitCompletion>> getCompletionsForTask(
    String userId,
    String taskName,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final results = await db.query(
      'habit_completions',
      where:
          'user_id = ? AND task_name = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, taskName, startDate, endDate],
      orderBy: 'date ASC',
    );
    return results.map(HabitCompletion.fromMap).toList();
  }

  /// All unique task names the user has ever tracked
  Future<List<Map<String, dynamic>>> getAllTrackedTasks(String userId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT task_name, MAX(date) as last_active,
             SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as total_completed
      FROM habit_completions
      WHERE user_id = ?
      GROUP BY task_name
      ORDER BY last_active DESC
    ''', [userId]);
    return results;
  }

  /// Calculate current streak for a specific task
  Future<int> getCurrentStreak(String userId, String taskName) async {
    final db = await database;
    final now = DateTime.now();
    final results = await db.query(
      'habit_completions',
      where: 'user_id = ? AND task_name = ? AND completed = 1',
      whereArgs: [userId, taskName],
      orderBy: 'date DESC',
    );
    if (results.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    // Check if last active was today or yesterday
    final lastDate = DateTime.parse(results.first['date'] as String);
    final diff = checkDate.difference(lastDate).inDays;
    if (diff > 1) return 0;
    if (diff == 1) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    final dateSet = results
        .map((r) => r['date'] as String)
        .toSet();

    while (true) {
      final dateStr =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dateSet.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Calculate longest streak for a specific task
  Future<int> getLongestStreak(String userId, String taskName) async {
    final db = await database;
    final results = await db.query(
      'habit_completions',
      columns: ['date'],
      where: 'user_id = ? AND task_name = ? AND completed = 1',
      whereArgs: [userId, taskName],
      orderBy: 'date ASC',
    );
    if (results.isEmpty) return 0;

    final dates = results.map((r) => DateTime.parse(r['date'] as String)).toList();
    int longest = 1;
    int current = 1;

    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  /// Best streak info for streak banner: task with highest current streak >= 3
  Future<Map<String, dynamic>?> getBestActiveStreak(String userId) async {
    final db = await database;
    final now = DateTime.now();
    final sixtyDaysAgo = now.subtract(const Duration(days: 60));
    final startStr =
        '${sixtyDaysAgo.year}-${sixtyDaysAgo.month.toString().padLeft(2, '0')}-${sixtyDaysAgo.day.toString().padLeft(2, '0')}';

    final tasks = await db.rawQuery('''
      SELECT DISTINCT task_name FROM habit_completions
      WHERE user_id = ? AND date >= ? AND completed = 1
    ''', [userId, startStr]);

    String? bestTask;
    int bestStreak = 0;

    for (final row in tasks) {
      final taskName = row['task_name'] as String;
      final streak = await getCurrentStreak(userId, taskName);
      if (streak >= 3 && streak > bestStreak) {
        bestStreak = streak;
        bestTask = taskName;
      }
    }

    if (bestTask == null) return null;
    return {'task_name': bestTask, 'streak': bestStreak};
  }

  // ──────────────────────────── Reminders ────────────────────────────

  Future<List<FocusReminder>> getReminders(String userId) async {
    final db = await database;
    final results = await db.query(
      'reminders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return results.map(FocusReminder.fromMap).toList();
  }

  Future<List<FocusReminder>> getActiveReminders(String userId) async {
    final db = await database;
    final results = await db.query(
      'reminders',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
    );
    return results.map(FocusReminder.fromMap).toList();
  }

  Future<void> saveReminder(FocusReminder reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReminder(String reminderId) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [reminderId]);
  }

  Future<FocusReminder?> getReminder(String id) async {
    final db = await database;
    final results = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FocusReminder.fromMap(results.first);
  }

  Future<void> updateReminderGcalId(String reminderId, String? gcalEventId) async {
    final db = await database;
    await db.update(
      'reminders',
      {'gcal_event_id': gcalEventId},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  // ──────────────────────────── Templates ────────────────────────────

  Future<String?> getUserTemplate(String userId) async {
    final db = await database;
    final results = await db.query(
      'focus_templates',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['content'] as String;
  }

  Future<void> saveUserTemplate(String userId, String content) async {
    final db = await database;
    await db.insert(
      'focus_templates',
      {
        'user_id': userId,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ──────────────────────────── Pending Sync ────────────────────────────

  Future<List<FocusNote>> getPendingNotes() async {
    final db = await database;
    final results = await db.query(
      'daily_notes',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return results.map(FocusNote.fromMap).toList();
  }

  Future<List<FocusUserHabits>> getPendingUserHabits() async {
    final db = await database;
    final results = await db.query(
      'focus_user_habits',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return results.map(FocusUserHabits.fromMap).toList();
  }

  Future<List<HabitCompletion>> getPendingCompletions() async {
    final db = await database;
    final results = await db.query(
      'habit_completions',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return results.map(HabitCompletion.fromMap).toList();
  }

  Future<void> markNoteSynced(String userId, String date) async {
    final db = await database;
    await db.update(
      'daily_notes',
      {'sync_status': 'synced'},
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
  }

  Future<void> markUserHabitsSynced(String userId) async {
    final db = await database;
    await db.update(
      'focus_user_habits',
      {'sync_status': 'synced'},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> markCompletionsSynced(String userId, String date) async {
    final db = await database;
    await db.update(
      'habit_completions',
      {'sync_status': 'synced'},
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
  }

  Future<void> markReminderSynced(String reminderId) async {
    final db = await database;
    await db.update(
      'reminders',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  // ──────────────────────────── New Habits Tracker (Loop) ────────────────────────────

  Future<List<FocusHabit>> getHabits(String userId, {bool includeArchived = false}) async {
    final db = await database;
    final results = await db.query(
      'habits',
      where: includeArchived ? 'user_id = ?' : 'user_id = ? AND is_archived = 0',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return results.map(FocusHabit.fromMap).toList();
  }

  Future<FocusHabit?> getHabit(String id) async {
    final db = await database;
    final results = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FocusHabit.fromMap(results.first);
  }

  Future<void> saveHabit(FocusHabit habit) async {
    final db = await database;
    await db.insert(
      'habits',
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteHabit(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('habits', where: 'id = ?', whereArgs: [id]);
      await txn.delete('habit_records', where: 'habit_id = ?', whereArgs: [id]);
    });
  }

  Future<List<HabitRecord>> getRecordsForHabit(String habitId) async {
    final db = await database;
    final results = await db.query(
      'habit_records',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'date ASC',
    );
    return results.map(HabitRecord.fromMap).toList();
  }

  Future<List<HabitRecord>> getRecordsForUser(String userId, String date) async {
    final db = await database;
    final results = await db.query(
      'habit_records',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
    return results.map(HabitRecord.fromMap).toList();
  }

  Future<HabitRecord?> getRecord(String habitId, String date) async {
    final db = await database;
    final results = await db.query(
      'habit_records',
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, date],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return HabitRecord.fromMap(results.first);
  }

  Future<void> saveRecord(HabitRecord record) async {
    final db = await database;
    await db.insert(
      'habit_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRecord(String habitId, String date) async {
    final db = await database;
    await db.delete(
      'habit_records',
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, date],
    );
  }

  // ──────────────────────────── New Pending Sync (Loop) ────────────────────────────

  Future<List<FocusHabit>> getPendingHabits() async {
    final db = await database;
    final results = await db.query(
      'habits',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return results.map(FocusHabit.fromMap).toList();
  }

  Future<List<HabitRecord>> getPendingRecords() async {
    final db = await database;
    final results = await db.query(
      'habit_records',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return results.map(HabitRecord.fromMap).toList();
  }

  Future<void> markHabitSynced(String id) async {
    final db = await database;
    await db.update(
      'habits',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markRecordSynced(String id) async {
    final db = await database;
    await db.update(
      'habit_records',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
