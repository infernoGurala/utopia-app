class UserTimetable {
  final List<TimetablePeriod> periods;
  final List<TimetableDay> week;

  const UserTimetable({
    required this.periods,
    required this.week,
  });

  factory UserTimetable.fromJson(Map<String, dynamic> json) {
    return UserTimetable(
      periods: (json['periods'] as List? ?? [])
          .map((e) => TimetablePeriod.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      week: (json['week'] as List? ?? [])
          .map((e) => TimetableDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'periods': periods.map((e) => e.toJson()).toList(),
      'week': week.map((e) => e.toJson()).toList(),
    };
  }
}

class TimetablePeriod {
  final int period;
  final String start;
  final String end;

  const TimetablePeriod({
    required this.period,
    required this.start,
    required this.end,
  });

  factory TimetablePeriod.fromJson(Map<String, dynamic> json) {
    return TimetablePeriod(
      period: json['period'] as int? ?? 0,
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'start': start,
      'end': end,
    };
  }
}

class TimetableDay {
  final String day;
  final List<String> slots;

  const TimetableDay({
    required this.day,
    required this.slots,
  });

  factory TimetableDay.fromJson(Map<String, dynamic> json) {
    return TimetableDay(
      day: json['day'] as String? ?? '',
      slots: (json['slots'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'slots': slots,
    };
  }
}
