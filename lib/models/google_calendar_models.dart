import 'dart:convert';

class GoogleCalendar {
  final String id;
  final String summary;
  final String? description;
  final String? backgroundColor;
  final String? foregroundColor;
  final bool selected;
  final String? accessRole;

  GoogleCalendar({
    required this.id,
    required this.summary,
    this.description,
    this.backgroundColor,
    this.foregroundColor,
    this.selected = true,
    this.accessRole,
  });

  GoogleCalendar copyWith({
    String? id,
    String? summary,
    String? description,
    String? backgroundColor,
    String? foregroundColor,
    bool? selected,
    String? accessRole,
  }) {
    return GoogleCalendar(
      id: id ?? this.id,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      selected: selected ?? this.selected,
      accessRole: accessRole ?? this.accessRole,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'summary': summary,
      'description': description,
      'background_color': backgroundColor,
      'foreground_color': foregroundColor,
      'selected': selected ? 1 : 0,
      'access_role': accessRole,
    };
  }

  factory GoogleCalendar.fromMap(Map<String, dynamic> map) {
    return GoogleCalendar(
      id: map['id'] as String,
      summary: map['summary'] as String,
      description: map['description'] as String?,
      backgroundColor: map['background_color'] as String?,
      foregroundColor: map['foreground_color'] as String?,
      selected: (map['selected'] ?? 1) == 1,
      accessRole: map['access_role'] as String?,
    );
  }
}

class GoogleCalendarEvent {
  final String id;
  final String calendarId;
  final String? summary;
  final String? description;
  final String? location;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isAllDay;
  final String? timezone;
  final String? rrule;
  final String? colorId;
  final String? hangoutLink;
  final String? creatorEmail;
  final String? organizerEmail;
  final String? visibility;
  final List<EventAttendee> attendees;
  final List<EventReminderOption> reminders;
  final List<EventAttachment> attachments;
  final int updatedAt;
  final bool isDeleted;
  final bool isDirty;

  GoogleCalendarEvent({
    required this.id,
    required this.calendarId,
    this.summary,
    this.description,
    this.location,
    DateTime? startTime,
    DateTime? endTime,
    this.isAllDay = false,
    this.timezone,
    this.rrule,
    this.colorId,
    this.hangoutLink,
    this.creatorEmail,
    this.organizerEmail,
    this.visibility,
    this.attendees = const [],
    this.reminders = const [],
    this.attachments = const [],
    required this.updatedAt,
    this.isDeleted = false,
    this.isDirty = false,
  })  : startTime = startTime?.toLocal(),
        endTime = endTime?.toLocal();

  GoogleCalendarEvent copyWith({
    String? id,
    String? calendarId,
    String? summary,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? timezone,
    String? rrule,
    String? colorId,
    String? hangoutLink,
    String? creatorEmail,
    String? organizerEmail,
    String? visibility,
    List<EventAttendee>? attendees,
    List<EventReminderOption>? reminders,
    List<EventAttachment>? attachments,
    int? updatedAt,
    bool? isDeleted,
    bool? isDirty,
  }) {
    return GoogleCalendarEvent(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      timezone: timezone ?? this.timezone,
      rrule: rrule ?? this.rrule,
      colorId: colorId ?? this.colorId,
      hangoutLink: hangoutLink ?? this.hangoutLink,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      visibility: visibility ?? this.visibility,
      attendees: attendees ?? this.attendees,
      reminders: reminders ?? this.reminders,
      attachments: attachments ?? this.attachments,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'calendar_id': calendarId,
      'summary': summary,
      'description': description,
      'location': location,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_all_day': isAllDay ? 1 : 0,
      'timezone': timezone,
      'rrule': rrule,
      'color_id': colorId,
      'hangout_link': hangoutLink,
      'creator_email': creatorEmail,
      'organizer_email': organizerEmail,
      'visibility': visibility,
      'attendees': jsonEncode(attendees.map((a) => a.toMap()).toList()),
      'reminders': jsonEncode(reminders.map((r) => r.toMap()).toList()),
      'attachments': jsonEncode(attachments.map((a) => a.toMap()).toList()),
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_dirty': isDirty ? 1 : 0,
    };
  }

  factory GoogleCalendarEvent.fromMap(Map<String, dynamic> map) {
    final attendeesList = map['attendees'] != null
        ? (jsonDecode(map['attendees'] as String) as List)
            .map((a) => EventAttendee.fromMap(a as Map<String, dynamic>))
            .toList()
        : const <EventAttendee>[];
    final remindersList = map['reminders'] != null
        ? (jsonDecode(map['reminders'] as String) as List)
            .map((r) => EventReminderOption.fromMap(r as Map<String, dynamic>))
            .toList()
        : const <EventReminderOption>[];
    final attachmentsList = map['attachments'] != null
        ? (jsonDecode(map['attachments'] as String) as List)
            .map((a) => EventAttachment.fromMap(a as Map<String, dynamic>))
            .toList()
        : const <EventAttachment>[];

    return GoogleCalendarEvent(
      id: map['id'] as String,
      calendarId: map['calendar_id'] as String,
      summary: map['summary'] as String?,
      description: map['description'] as String?,
      location: map['location'] as String?,
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'] as String)
          : null,
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'] as String)
          : null,
      isAllDay: (map['is_all_day'] ?? 0) == 1,
      timezone: map['timezone'] as String?,
      rrule: map['rrule'] as String?,
      colorId: map['color_id'] as String?,
      hangoutLink: map['hangout_link'] as String?,
      creatorEmail: map['creator_email'] as String?,
      organizerEmail: map['organizer_email'] as String?,
      visibility: map['visibility'] as String?,
      attendees: attendeesList,
      reminders: remindersList,
      attachments: attachmentsList,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
      isDirty: (map['is_dirty'] ?? 0) == 1,
    );
  }
}

class EventAttendee {
  final String? email;
  final String? displayName;
  final String? responseStatus; // 'accepted', 'declined', 'tentative', 'needsAction'

  EventAttendee({
    this.email,
    this.displayName,
    this.responseStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'responseStatus': responseStatus,
    };
  }

  factory EventAttendee.fromMap(Map<String, dynamic> map) {
    return EventAttendee(
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      responseStatus: map['responseStatus'] as String?,
    );
  }
}

class EventReminderOption {
  final String method; // 'popup', 'email'
  final int minutes;

  EventReminderOption({
    required this.method,
    required this.minutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'minutes': minutes,
    };
  }

  factory EventReminderOption.fromMap(Map<String, dynamic> map) {
    return EventReminderOption(
      method: map['method'] as String? ?? 'popup',
      minutes: map['minutes'] as int? ?? 10,
    );
  }
}

class EventAttachment {
  final String fileUrl;
  final String title;
  final String? mimeType;
  final String? iconLink;

  EventAttachment({
    required this.fileUrl,
    required this.title,
    this.mimeType,
    this.iconLink,
  });

  Map<String, dynamic> toMap() {
    return {
      'fileUrl': fileUrl,
      'title': title,
      'mimeType': mimeType,
      'iconLink': iconLink,
    };
  }

  factory EventAttachment.fromMap(Map<String, dynamic> map) {
    return EventAttachment(
      fileUrl: map['fileUrl'] as String,
      title: map['title'] as String? ?? 'Attachment',
      mimeType: map['mimeType'] as String?,
      iconLink: map['iconLink'] as String?,
    );
  }
}
