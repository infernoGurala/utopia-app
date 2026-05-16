import 'dart:convert';

/// Data models for the Focus productivity feature.
///
/// Three core models:
/// - [FocusNote] — one markdown note per user per date
/// - [HabitCompletion] — derived task completion rows for heatmap
/// - [FocusReminder] — scheduled reminders (one-time, weekly, monthly)

class FocusNote {
  final String? id;
  final String userId;
  final String date; // YYYY-MM-DD
  final Map<String, bool> habitsState; // { "habitName": true/false }
  final List<Map<String, dynamic>> tasks; // [ {"label": "Task", "completed": false} ]
  final String journal;
  final String syncStatus; // 'synced', 'pending'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FocusNote({
    this.id,
    required this.userId,
    required this.date,
    this.habitsState = const {},
    this.tasks = const [],
    this.journal = '',
    this.syncStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  FocusNote copyWith({
    String? id,
    String? userId,
    String? date,
    Map<String, bool>? habitsState,
    List<Map<String, dynamic>>? tasks,
    String? journal,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FocusNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      habitsState: habitsState ?? this.habitsState,
      tasks: tasks ?? this.tasks,
      journal: journal ?? this.journal,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'habits_state': jsonEncode(habitsState),
      'tasks': jsonEncode(tasks),
      'journal': journal,
      'sync_status': syncStatus,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory FocusNote.fromMap(Map<String, dynamic> map) {
    Map<String, bool> parsedHabits = {};
    if (map['habits_state'] != null) {
      if (map['habits_state'] is String) {
        try {
          final decoded = jsonDecode(map['habits_state'] as String) as Map;
          parsedHabits = decoded.map((k, v) => MapEntry(k.toString(), v == true));
        } catch (_) {}
      } else if (map['habits_state'] is Map) {
        parsedHabits = (map['habits_state'] as Map).map((k, v) => MapEntry(k.toString(), v == true));
      }
    }

    List<Map<String, dynamic>> parsedTasks = [];
    if (map['tasks'] != null) {
      if (map['tasks'] is String) {
        try {
          final decoded = jsonDecode(map['tasks'] as String) as List;
          parsedTasks = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      } else if (map['tasks'] is List) {
        parsedTasks = (map['tasks'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    return FocusNote(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      date: map['date'] as String,
      habitsState: parsedHabits,
      tasks: parsedTasks,
      journal: map['journal'] as String? ?? '',
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  /// Supabase row (no sync_status)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'user_id': userId,
      'date': date,
      'habits_state': habitsState, // Supabase JSONB natively takes Dart maps
      'tasks': tasks, // Supabase JSONB natively takes Dart lists
      'journal': journal,
    };
  }
}

class FocusUserHabits {
  final String userId;
  final List<String> habits;
  final String syncStatus;

  const FocusUserHabits({
    required this.userId,
    this.habits = const [],
    this.syncStatus = 'pending',
  });

  FocusUserHabits copyWith({
    String? userId,
    List<String>? habits,
    String? syncStatus,
  }) {
    return FocusUserHabits(
      userId: userId ?? this.userId,
      habits: habits ?? this.habits,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'habits': jsonEncode(habits),
      'sync_status': syncStatus,
    };
  }

  factory FocusUserHabits.fromMap(Map<String, dynamic> map) {
    List<String> parsedHabits = [];
    if (map['habits'] != null) {
      if (map['habits'] is String) {
        try {
          final decoded = jsonDecode(map['habits'] as String) as List;
          parsedHabits = decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      } else if (map['habits'] is List) {
        parsedHabits = (map['habits'] as List).map((e) => e.toString()).toList();
      }
    }
    return FocusUserHabits(
      userId: map['user_id'] as String,
      habits: parsedHabits,
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'user_id': userId,
      'habits': habits,
    };
  }
}

class HabitCompletion {
  final String? id;
  final String userId;
  final String date; // YYYY-MM-DD
  final String taskName; // lowercased, trimmed
  final bool completed;
  final int completionCount;
  final String syncStatus;

  const HabitCompletion({
    this.id,
    required this.userId,
    required this.date,
    required this.taskName,
    required this.completed,
    this.completionCount = 1,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'task_name': taskName,
      'completed': completed ? 1 : 0,
      'completion_count': completionCount,
      'sync_status': syncStatus,
    };
  }

  factory HabitCompletion.fromMap(Map<String, dynamic> map) {
    return HabitCompletion(
      id: map['id']?.toString(),
      userId: map['user_id'] as String,
      date: map['date'] as String,
      taskName: map['task_name'] as String,
      completed: (map['completed'] is bool)
          ? map['completed'] as bool
          : (map['completed'] as int) == 1,
      completionCount: (map['completion_count'] as int?) ?? 1,
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'user_id': userId,
      'date': date,
      'task_name': taskName,
      'completed': completed,
      'completion_count': completionCount,
    };
  }
}

class FocusReminder {
  final String? id;
  final String userId;
  final String label;
  final String type; // 'one_time', 'weekly', 'monthly_date'
  final String reminderTime; // HH:MM (24h)
  final String? remindDate; // YYYY-MM-DD, only for one_time
  final List<int>? weekdays; // 0=Mon … 6=Sun, for weekly
  final int? monthDay; // 1–28, for monthly_date
  final List<int>? activeMonths; // 1–12, null = all months
  final bool isActive;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FocusReminder({
    this.id,
    required this.userId,
    required this.label,
    required this.type,
    required this.reminderTime,
    this.remindDate,
    this.weekdays,
    this.monthDay,
    this.activeMonths,
    this.isActive = true,
    this.syncStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  FocusReminder copyWith({
    String? id,
    String? userId,
    String? label,
    String? type,
    String? reminderTime,
    String? remindDate,
    List<int>? weekdays,
    int? monthDay,
    List<int>? activeMonths,
    bool? isActive,
    String? syncStatus,
  }) {
    return FocusReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      type: type ?? this.type,
      reminderTime: reminderTime ?? this.reminderTime,
      remindDate: remindDate ?? this.remindDate,
      weekdays: weekdays ?? this.weekdays,
      monthDay: monthDay ?? this.monthDay,
      activeMonths: activeMonths ?? this.activeMonths,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'label': label,
      'type': type,
      'reminder_time': reminderTime,
      'remind_date': remindDate,
      'weekdays': weekdays?.join(','),
      'month_day': monthDay,
      'active_months': activeMonths?.join(','),
      'is_active': isActive ? 1 : 0,
      'sync_status': syncStatus,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory FocusReminder.fromMap(Map<String, dynamic> map) {
    return FocusReminder(
      id: map['id']?.toString(),
      userId: map['user_id'] as String,
      label: map['label'] as String,
      type: map['type'] as String,
      reminderTime: map['reminder_time'] as String,
      remindDate: map['remind_date'] as String?,
      weekdays: map['weekdays'] != null
          ? (map['weekdays'] as String).split(',').map(int.parse).toList()
          : null,
      monthDay: map['month_day'] as int?,
      activeMonths: map['active_months'] != null
          ? (map['active_months'] as String).split(',').map(int.parse).toList()
          : null,
      isActive: (map['is_active'] is bool)
          ? map['is_active'] as bool
          : (map['is_active'] as int) == 1,
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'user_id': userId,
      'label': label,
      'type': type,
      'reminder_time': reminderTime,
      if (remindDate != null) 'remind_date': remindDate,
      if (weekdays != null) 'weekdays': weekdays,
      if (monthDay != null) 'month_day': monthDay,
      if (activeMonths != null) 'active_months': activeMonths,
      'is_active': isActive,
    };
  }

  /// Human-readable summary of this reminder's schedule
  String get scheduleSummary {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final timeParts = reminderTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = timeParts[1];
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeStr = '$displayHour:$minute $ampm';

    switch (type) {
      case 'one_time':
        if (remindDate != null) {
          final parts = remindDate!.split('-');
          final m = int.parse(parts[1]);
          return '${parts[2]} ${monthNames[m]} ${parts[0]} · $timeStr';
        }
        return timeStr;
      case 'weekly':
        if (weekdays != null && weekdays!.isNotEmpty) {
          final days = weekdays!.map((d) => dayNames[d]).join(', ');
          return 'Every $days · $timeStr';
        }
        return 'Weekly · $timeStr';
      case 'monthly_date':
        final daySuffix = _ordinal(monthDay ?? 1);
        if (activeMonths != null && activeMonths!.isNotEmpty) {
          final months = activeMonths!.map((m) => monthNames[m]).join(', ');
          return 'Every $daySuffix of $months · $timeStr';
        }
        return 'Every $daySuffix · $timeStr';
      default:
        return timeStr;
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}

/// Parsed data from a daily note's Tasks section
class ExtractedTask {
  final String taskName; // original casing
  final String normalizedName; // lowercased, trimmed
  final bool completed;

  const ExtractedTask({
    required this.taskName,
    required this.normalizedName,
    required this.completed,
  });
}
