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
  final String? description;
  final String? habitId;
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
  final String? gcalEventId; // linked Google Calendar event ID

  const FocusReminder({
    this.id,
    required this.userId,
    required this.label,
    this.description,
    this.habitId,
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
    this.gcalEventId,
  });

  FocusReminder copyWith({
    String? id,
    String? userId,
    String? label,
    String? description,
    String? habitId,
    String? type,
    String? reminderTime,
    String? remindDate,
    List<int>? weekdays,
    int? monthDay,
    List<int>? activeMonths,
    bool? isActive,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? gcalEventId,
  }) {
    return FocusReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      description: description ?? this.description,
      habitId: habitId ?? this.habitId,
      type: type ?? this.type,
      reminderTime: reminderTime ?? this.reminderTime,
      remindDate: remindDate ?? this.remindDate,
      weekdays: weekdays ?? this.weekdays,
      monthDay: monthDay ?? this.monthDay,
      activeMonths: activeMonths ?? this.activeMonths,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      gcalEventId: gcalEventId ?? this.gcalEventId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'label': label,
      'description': description,
      'habit_id': habitId,
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
      'gcal_event_id': gcalEventId,
    };
  }

  factory FocusReminder.fromMap(Map<String, dynamic> map) {
    List<int>? parsedWeekdays;
    if (map['weekdays'] != null) {
      if (map['weekdays'] is List) {
        parsedWeekdays = (map['weekdays'] as List)
            .map((e) => e is int ? e : int.parse(e.toString()))
            .toList();
      } else if (map['weekdays'] is String && (map['weekdays'] as String).isNotEmpty) {
        parsedWeekdays = (map['weekdays'] as String)
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .map(int.parse)
            .toList();
      }
    }

    List<int>? parsedActiveMonths;
    if (map['active_months'] != null) {
      if (map['active_months'] is List) {
        parsedActiveMonths = (map['active_months'] as List)
            .map((e) => e is int ? e : int.parse(e.toString()))
            .toList();
      } else if (map['active_months'] is String && (map['active_months'] as String).isNotEmpty) {
        parsedActiveMonths = (map['active_months'] as String)
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .map(int.parse)
            .toList();
      }
    }

    return FocusReminder(
      id: map['id']?.toString(),
      userId: map['user_id'] as String,
      label: map['label'] as String,
      description: map['description'] as String?,
      habitId: map['habit_id'] as String?,
      type: map['type'] as String,
      reminderTime: map['reminder_time'] as String,
      remindDate: map['remind_date'] as String?,
      weekdays: parsedWeekdays,
      monthDay: map['month_day'] as int?,
      activeMonths: parsedActiveMonths,
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
      gcalEventId: map['gcal_event_id'] as String?,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'user_id': userId,
      'label': label,
      if (description != null) 'description': description,
      if (habitId != null) 'habit_id': habitId,
      'type': type,
      'reminder_time': reminderTime,
      if (remindDate != null) 'remind_date': remindDate,
      if (weekdays != null) 'weekdays': weekdays,
      if (monthDay != null) 'month_day': monthDay,
      if (activeMonths != null) 'active_months': activeMonths,
      'is_active': isActive,
      if (gcalEventId != null) 'gcal_event_id': gcalEventId,
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
      case 'daily':
        return 'Every day · $timeStr';
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

  bool get isCompleted {
    if (type == 'one_time' && remindDate != null) {
      try {
        final dateParts = remindDate!.split('-');
        final timeParts = reminderTime.split(':');
        final scheduled = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        return scheduled.isBefore(DateTime.now());
      } catch (_) {
        return false;
      }
    }
    return false;
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

class FocusHabit {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String type; // 'binary', 'measurable'
  final double targetValue;
  final String? unit;
  final String frequencyType; // 'daily', 'days_of_week', 'weekly', 'monthly', 'interval'
  final int frequencyValue;
  final List<int>? daysOfWeek; // 0=Mon ... 6=Sun
  final String? reminderTime; // HH:MM (24h)
  final String color; // hex string color, e.g. '#08BB68'
  final bool isArchived;
  final String syncStatus; // 'synced', 'pending'
  final DateTime createdAt;
  final DateTime updatedAt;

  const FocusHabit({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.type = 'binary',
    this.targetValue = 1.0,
    this.unit,
    this.frequencyType = 'daily',
    this.frequencyValue = 1,
    this.daysOfWeek,
    this.reminderTime,
    this.color = '#08BB68',
    this.isArchived = false,
    this.syncStatus = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  FocusHabit copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? type,
    double? targetValue,
    String? unit,
    String? frequencyType,
    int? frequencyValue,
    List<int>? daysOfWeek,
    String? reminderTime,
    String? color,
    bool? isArchived,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FocusHabit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyValue: frequencyValue ?? this.frequencyValue,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      reminderTime: reminderTime ?? this.reminderTime,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'type': type,
      'target_value': targetValue,
      'unit': unit,
      'frequency_type': frequencyType,
      'frequency_value': frequencyValue,
      'days_of_week': daysOfWeek?.join(','),
      'reminder_time': reminderTime,
      'color': color,
      'is_archived': isArchived ? 1 : 0,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FocusHabit.fromMap(Map<String, dynamic> map) {
    List<int>? parsedDays;
    if (map['days_of_week'] != null && map['days_of_week'].toString().isNotEmpty) {
      try {
        parsedDays = map['days_of_week']
            .toString()
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .map((s) => int.parse(s.trim()))
            .toList();
      } catch (_) {}
    }
    return FocusHabit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      type: map['type'] as String? ?? 'binary',
      targetValue: (map['target_value'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String?,
      frequencyType: map['frequency_type'] as String? ?? 'daily',
      frequencyValue: map['frequency_value'] as int? ?? 1,
      daysOfWeek: parsedDays,
      reminderTime: map['reminder_time'] as String?,
      color: map['color'] as String? ?? '#08BB68',
      isArchived: (map['is_archived'] is bool)
          ? map['is_archived'] as bool
          : (map['is_archived'] as int? ?? 0) == 1,
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'type': type,
      'target_value': targetValue,
      'unit': unit,
      'frequency_type': frequencyType,
      'frequency_value': frequencyValue,
      'days_of_week': daysOfWeek?.join(','), // Represent as a string for safety in supabase too or array depending on setup
      'reminder_time': reminderTime,
      'color': color,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class HabitRecord {
  final String id;
  final String habitId;
  final String userId;
  final String date; // YYYY-MM-DD
  final double value;
  final double targetValue;
  final bool completed;
  final String? note;
  final String syncStatus;
  final DateTime updatedAt;

  const HabitRecord({
    required this.id,
    required this.habitId,
    required this.userId,
    required this.date,
    this.value = 0.0,
    this.targetValue = 1.0,
    this.completed = false,
    this.note,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  HabitRecord copyWith({
    String? id,
    String? habitId,
    String? userId,
    String? date,
    double? value,
    double? targetValue,
    bool? completed,
    String? note,
    String? syncStatus,
    DateTime? updatedAt,
  }) {
    return HabitRecord(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      value: value ?? this.value,
      targetValue: targetValue ?? this.targetValue,
      completed: completed ?? this.completed,
      note: note ?? this.note,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'date': date,
      'value': value,
      'target_value': targetValue,
      'completed': completed ? 1 : 0,
      'note': note,
      'sync_status': syncStatus,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HabitRecord.fromMap(Map<String, dynamic> map) {
    return HabitRecord(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      userId: map['user_id'] as String,
      date: map['date'] as String,
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      targetValue: (map['target_value'] as num?)?.toDouble() ?? 1.0,
      completed: (map['completed'] is bool)
          ? map['completed'] as bool
          : (map['completed'] as int? ?? 0) == 1,
      note: map['note'] as String?,
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'date': date,
      'value': value,
      'target_value': targetValue,
      'completed': completed,
      'note': note,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

