import '../models/focus_models.dart';

class HabitCalculators {
  /// Calculate habit strength (0.0 to 1.0) using exponential moving average
  static double calculateStrength(FocusHabit habit, List<HabitRecord> records) {
    if (records.isEmpty) return 0.0;

    // Map completions by date
    final completionMap = <String, bool>{};
    for (final r in records) {
      completionMap[r.date] = r.completed;
    }

    // Determine start date
    DateTime startDate = habit.createdAt;
    if (records.isNotEmpty) {
      records.sort((a, b) => a.date.compareTo(b.date));
      final firstRecordDate = DateTime.parse(records.first.date);
      if (firstRecordDate.isBefore(startDate)) {
        startDate = firstRecordDate;
      }
    }

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final startStart = DateTime(startDate.year, startDate.month, startDate.day);
    
    double strength = 0.0;
    const double alpha = 0.1; // Learning rate

    // Standard daily habit
    if (habit.frequencyType == 'daily') {
      int days = todayStart.difference(startStart).inDays + 1;
      for (int i = 0; i < days; i++) {
        final checkDate = startStart.add(Duration(days: i));
        final dateStr = _dateStr(checkDate);
        final completed = completionMap[dateStr] == true;

        if (completed) {
          strength = strength + (1.0 - strength) * alpha;
        } else {
          strength = strength * (1.0 - alpha);
        }
      }
      return strength.clamp(0.0, 1.0);
    }

    // Days of Week habit (e.g. Mon, Wed, Fri)
    if (habit.frequencyType == 'days_of_week') {
      final scheduledDays = habit.daysOfWeek ?? [];
      if (scheduledDays.isEmpty) return 0.0;

      int days = todayStart.difference(startStart).inDays + 1;
      for (int i = 0; i < days; i++) {
        final checkDate = startStart.add(Duration(days: i));
        // weekday in Dart is 1=Mon ... 7=Sun. Convert to 0=Mon ... 6=Sun
        final weekday = checkDate.weekday - 1;

        if (scheduledDays.contains(weekday)) {
          final dateStr = _dateStr(checkDate);
          final completed = completionMap[dateStr] == true;

          if (completed) {
            strength = strength + (1.0 - strength) * alpha;
          } else {
            strength = strength * (1.0 - alpha);
          }
        }
      }
      return strength.clamp(0.0, 1.0);
    }

    // Weekly habit (e.g. 3 times per week)
    if (habit.frequencyType == 'weekly') {
      final target = habit.frequencyValue;
      // Loop week-by-week (Monday to Sunday)
      DateTime currentWeekStart = startStart.subtract(Duration(days: startStart.weekday - 1));
      
      while (currentWeekStart.isBefore(todayStart) || 
             _isSameDay(currentWeekStart, todayStart)) {
        int completionsInWeek = 0;
        
        for (int d = 0; d < 7; d++) {
          final day = currentWeekStart.add(Duration(days: d));
          if (day.isAfter(todayStart)) break;
          final dateStr = _dateStr(day);
          if (completionMap[dateStr] == true) {
            completionsInWeek++;
          }
        }

        final success = completionsInWeek >= target;
        if (success) {
          strength = strength + (1.0 - strength) * alpha;
        } else {
          strength = strength * (1.0 - alpha);
        }

        currentWeekStart = currentWeekStart.add(const Duration(days: 7));
      }
      return strength.clamp(0.0, 1.0);
    }

    // Monthly habit (e.g. 10 times per month)
    if (habit.frequencyType == 'monthly') {
      final target = habit.frequencyValue;
      DateTime currentMonthStart = DateTime(startStart.year, startStart.month, 1);
      
      while (currentMonthStart.isBefore(todayStart) || 
             (currentMonthStart.year == todayStart.year && currentMonthStart.month == todayStart.month)) {
        int completionsInMonth = 0;
        final lastDay = DateTime(currentMonthStart.year, currentMonthStart.month + 1, 0).day;

        for (int d = 1; d <= lastDay; d++) {
          final day = DateTime(currentMonthStart.year, currentMonthStart.month, d);
          if (day.isAfter(todayStart)) break;
          final dateStr = _dateStr(day);
          if (completionMap[dateStr] == true) {
            completionsInMonth++;
          }
        }

        final success = completionsInMonth >= target;
        if (success) {
          strength = strength + (1.0 - strength) * alpha;
        } else {
          strength = strength * (1.0 - alpha);
        }

        currentMonthStart = DateTime(currentMonthStart.year, currentMonthStart.month + 1, 1);
      }
      return strength.clamp(0.0, 1.0);
    }

    // Interval habit (e.g. every 3 days)
    if (habit.frequencyType == 'interval') {
      final interval = habit.frequencyValue;
      if (interval <= 0) return 0.0;

      int dayCount = todayStart.difference(startStart).inDays + 1;
      int intervalCompletions = 0;

      for (int i = 0; i < dayCount; i++) {
        final checkDate = startStart.add(Duration(days: i));
        final dateStr = _dateStr(checkDate);
        if (completionMap[dateStr] == true) {
          intervalCompletions++;
        }

        // Trigger updates on the end of each interval cycle
        if ((i + 1) % interval == 0 || i == dayCount - 1) {
          final success = intervalCompletions > 0;
          if (success) {
            strength = strength + (1.0 - strength) * alpha;
          } else {
            strength = strength * (1.0 - alpha);
          }
          intervalCompletions = 0;
        }
      }
      return strength.clamp(0.0, 1.0);
    }

    return 0.0;
  }

  /// Calculate the current active streak in consecutive scheduled days
  static int calculateCurrentStreak(FocusHabit habit, List<HabitRecord> records) {
    if (records.isEmpty) return 0;

    final completedDates = records
        .where((r) => r.completed)
        .map((r) => r.date)
        .toSet();

    if (completedDates.isEmpty) return 0;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    // Streaks for YES/NO or Daily frequencies are counted day-by-day
    if (habit.frequencyType == 'daily') {
      int streak = 0;
      DateTime checkDate = todayStart;

      // Loop backward until we find a day without completion
      while (true) {
        final dateStr = _dateStr(checkDate);
        if (completedDates.contains(dateStr)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          // If we missed today, the streak could still be alive if yesterday was completed
          if (checkDate == todayStart) {
            checkDate = checkDate.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
      }
      return streak;
    }

    // Streaks for custom weekdays
    if (habit.frequencyType == 'days_of_week') {
      final scheduledDays = habit.daysOfWeek ?? [];
      if (scheduledDays.isEmpty) return 0;

      int streak = 0;
      DateTime checkDate = todayStart;

      while (true) {
        final weekday = checkDate.weekday - 1;
        if (scheduledDays.contains(weekday)) {
          final dateStr = _dateStr(checkDate);
          if (completedDates.contains(dateStr)) {
            streak++;
          } else {
            // Check if streak was active as of yesterday
            if (checkDate == todayStart) {
              checkDate = checkDate.subtract(const Duration(days: 1));
              continue;
            }
            break;
          }
        }
        checkDate = checkDate.subtract(const Duration(days: 1));
        
        // Stop checking if we are going too far back beyond the earliest completed date
        if (streak > 0 && checkDate.isBefore(DateTime.parse(records.first.date).subtract(const Duration(days: 7)))) {
          break;
        }
      }
      return streak;
    }

    // For weekly, monthly, and interval habits, streak is defined as successful consecutive weeks/months/cycles
    // We can evaluate streaks by sorted completed logs sorted chronologically
    records.sort((a, b) => a.date.compareTo(b.date));
    int streak = 0;
    DateTime checkDate = todayStart;

    // Simple consecutive completed days fallback for remaining types
    while (true) {
      final dateStr = _dateStr(checkDate);
      if (completedDates.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        if (checkDate == todayStart) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }
    return streak;
  }

  /// Calculate the best (longest) streak all-time
  static int calculateBestStreak(FocusHabit habit, List<HabitRecord> records) {
    if (records.isEmpty) return 0;

    final completedDates = records
        .where((r) => r.completed)
        .map((r) => DateTime.parse(r.date))
        .toList();
    
    if (completedDates.isEmpty) return 0;
    completedDates.sort();

    int longest = 0;
    int current = 0;
    DateTime? prevDate;

    if (habit.frequencyType == 'daily') {
      for (final date in completedDates) {
        if (prevDate == null) {
          current = 1;
        } else {
          final diff = date.difference(prevDate).inDays;
          if (diff == 1) {
            current++;
          } else if (diff > 1) {
            current = 1;
          }
        }
        if (current > longest) longest = current;
        prevDate = date;
      }
      return longest;
    }

    if (habit.frequencyType == 'days_of_week') {
      final scheduledDays = habit.daysOfWeek ?? [];
      if (scheduledDays.isEmpty) return 0;

      for (final date in completedDates) {
        if (prevDate == null) {
          current = 1;
        } else {
          // Count how many scheduled days were between prevDate and date
          int scheduledDaysBetween = 0;
          int daysDiff = date.difference(prevDate).inDays;
          for (int d = 1; d < daysDiff; d++) {
            final checkDay = prevDate.add(Duration(days: d));
            if (scheduledDays.contains(checkDay.weekday - 1)) {
              scheduledDaysBetween++;
            }
          }
          
          if (scheduledDaysBetween == 0) {
            current++; // Completed consecutively on scheduled days!
          } else {
            current = 1; // Missed a scheduled day
          }
        }
        if (current > longest) longest = current;
        prevDate = date;
      }
      return longest;
    }

    // Default sequential calculation
    for (final date in completedDates) {
      if (prevDate == null) {
        current = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          current++;
        } else if (diff > 1) {
          current = 1;
        }
      }
      if (current > longest) longest = current;
      prevDate = date;
    }
    return longest;
  }

  /// Calculate the completion percentage rate
  static double calculateCompletionRate(FocusHabit habit, List<HabitRecord> records) {
    if (records.isEmpty) return 0.0;
    
    // Total checked completed days
    final completedCount = records.where((r) => r.completed).length;

    // Total scheduled days since creation
    DateTime startDate = habit.createdAt;
    records.sort((a, b) => a.date.compareTo(b.date));
    final firstRecordDate = DateTime.parse(records.first.date);
    if (firstRecordDate.isBefore(startDate)) {
      startDate = firstRecordDate;
    }

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final startStart = DateTime(startDate.year, startDate.month, startDate.day);
    int totalDays = todayStart.difference(startStart).inDays + 1;

    if (totalDays <= 0) return 0.0;

    if (habit.frequencyType == 'daily') {
      return (completedCount / totalDays).clamp(0.0, 1.0);
    }

    if (habit.frequencyType == 'days_of_week') {
      final scheduledDays = habit.daysOfWeek ?? [];
      if (scheduledDays.isEmpty) return 0.0;

      int scheduledCount = 0;
      for (int i = 0; i < totalDays; i++) {
        final checkDate = startStart.add(Duration(days: i));
        if (scheduledDays.contains(checkDate.weekday - 1)) {
          scheduledCount++;
        }
      }
      if (scheduledCount == 0) return 0.0;
      return (completedCount / scheduledCount).clamp(0.0, 1.0);
    }

    // For weekly, monthly, interval etc., divide total completed records by the total days since creation
    return (completedCount / totalDays).clamp(0.0, 1.0);
  }

  // Helper date parsing
  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
