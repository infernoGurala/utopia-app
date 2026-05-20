

/// Status of an event in its lifecycle.
enum EventStatus {
  upcoming,
  registrationOpen,
  almostFull,
  liveNow,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case EventStatus.upcoming:
        return 'Upcoming';
      case EventStatus.registrationOpen:
        return 'Registration Open';
      case EventStatus.almostFull:
        return 'Almost Full';
      case EventStatus.liveNow:
        return 'Live Now';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }

  static EventStatus fromString(String? s) {
    switch (s) {
      case 'upcoming':
        return EventStatus.upcoming;
      case 'registration_open':
        return EventStatus.registrationOpen;
      case 'almost_full':
        return EventStatus.almostFull;
      case 'live_now':
        return EventStatus.liveNow;
      case 'completed':
        return EventStatus.completed;
      case 'cancelled':
        return EventStatus.cancelled;
      default:
        return EventStatus.upcoming;
    }
  }

  String toDbString() {
    switch (this) {
      case EventStatus.upcoming:
        return 'upcoming';
      case EventStatus.registrationOpen:
        return 'registration_open';
      case EventStatus.almostFull:
        return 'almost_full';
      case EventStatus.liveNow:
        return 'live_now';
      case EventStatus.completed:
        return 'completed';
      case EventStatus.cancelled:
        return 'cancelled';
    }
  }
}

/// Complete event data model for the Utopia Events Ecosystem.
class EventModel {
  final String? id;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String category;
  final List<String> tags;

  // Images (Cloudinary URLs)
  final String? bannerUrl;
  final String? posterUrl;

  // Scheduling
  final DateTime date;
  final String startTime;
  final String endTime;
  final String venue;
  final int participantLimit;
  final DateTime? registrationDeadline;

  // Organizer
  final String organizerUid;
  final String organizerName;
  final String conductedBy;
  final String contactNumbers;
  final String? whatsappLink;
  final String? participationLink;

  // Flags
  final bool providesAttendance;
  final bool requiresPayment;
  final String? feeAmount;
  final bool providesCertificate;
  final String? permissionLetterUrl;

  // Status & stats
  final EventStatus status;
  final bool isApproved;
  final bool isFeatured;
  final int participantCount;
  final int viewCount;
  final int shareCount;
  final int likeCount;

  bool get isAdityaEvent {
    final venueLower = venue.toLowerCase();
    final conductedLower = conductedBy.toLowerCase();
    final orgLower = organizerName.toLowerCase();
    return venueLower.contains('aditya') || 
           conductedLower.contains('aditya') || 
           orgLower.contains('aditya');
  }

  // Metadata
  final String? universityId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Prize info
  final String? prizeInfo;
  final String? requirements;

  const EventModel({
    this.id,
    required this.title,
    this.shortDescription = '',
    this.fullDescription = '',
    required this.category,
    this.tags = const [],
    this.bannerUrl,
    this.posterUrl,
    required this.date,
    this.startTime = '',
    this.endTime = '',
    required this.venue,
    this.participantLimit = 0,
    this.registrationDeadline,
    required this.organizerUid,
    this.organizerName = '',
    this.conductedBy = '',
    this.contactNumbers = '',
    this.whatsappLink,
    this.participationLink,
    this.providesAttendance = false,
    this.requiresPayment = false,
    this.feeAmount,
    this.providesCertificate = false,
    this.permissionLetterUrl,
    this.status = EventStatus.upcoming,
    this.isApproved = false,
    this.isFeatured = false,
    this.participantCount = 0,
    this.viewCount = 0,
    this.shareCount = 0,
    this.likeCount = 0,
    this.universityId,
    this.createdAt,
    this.updatedAt,
    this.prizeInfo,
    this.requirements,
  });

  /// Deserialize from Supabase row.
  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] as String?,
      title: (map['title'] as String?) ?? '',
      shortDescription: (map['short_description'] as String?) ?? '',
      fullDescription: (map['full_description'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Tech',
      tags: _parseTags(map['tags']),
      bannerUrl: map['banner_url'] as String?,
      posterUrl: map['poster_url'] as String?,
      date: DateTime.tryParse((map['date'] as String?) ?? '') ?? DateTime.now(),
      startTime: (map['start_time'] as String?) ?? '',
      endTime: (map['end_time'] as String?) ?? '',
      venue: (map['venue'] as String?) ?? '',
      participantLimit: (map['participant_limit'] as int?) ?? 0,
      registrationDeadline: map['registration_deadline'] != null
          ? DateTime.tryParse(map['registration_deadline'] as String)
          : null,
      organizerUid: (map['organizer_uid'] as String?) ?? '',
      organizerName: (map['organizer_name'] as String?) ?? '',
      conductedBy: (map['conducted_by'] as String?) ?? '',
      contactNumbers: (map['contact_numbers'] as String?) ?? '',
      whatsappLink: map['whatsapp_link'] as String?,
      participationLink: map['participation_link'] as String?,
      providesAttendance: (map['provides_attendance'] as bool?) ?? false,
      requiresPayment: (map['requires_payment'] as bool?) ?? false,
      feeAmount: map['fee_amount'] as String?,
      providesCertificate: (map['provides_certificate'] as bool?) ?? false,
      permissionLetterUrl: map['permission_letter_url'] as String?,
      status: EventStatus.fromString(map['status'] as String?),
      isApproved: (map['is_approved'] as bool?) ?? false,
      isFeatured: (map['is_featured'] as bool?) ?? false,
      participantCount: (map['participant_count'] as int?) ?? 0,
      viewCount: (map['view_count'] as int?) ?? 0,
      shareCount: (map['share_count'] as int?) ?? 0,
      likeCount: (map['like_count'] as int?) ?? 0,
      universityId: map['university_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      prizeInfo: map['prize_info'] as String?,
      requirements: map['requirements'] as String?,
    );
  }

  /// Serialize for Supabase insert/update.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'short_description': shortDescription,
      'full_description': fullDescription,
      'category': category,
      'tags': tags,
      'banner_url': bannerUrl,
      'poster_url': posterUrl,
      'date': date.toIso8601String().split('T').first,
      'start_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'participant_limit': participantLimit,
      'registration_deadline': registrationDeadline?.toIso8601String(),
      'organizer_uid': organizerUid,
      'organizer_name': organizerName,
      'conducted_by': conductedBy,
      'contact_numbers': contactNumbers,
      'whatsapp_link': whatsappLink,
      'participation_link': participationLink,
      'provides_attendance': providesAttendance,
      'requires_payment': requiresPayment,
      'fee_amount': feeAmount,
      'provides_certificate': providesCertificate,
      'permission_letter_url': permissionLetterUrl,
      'status': status.toDbString(),
      'is_approved': isApproved,
      'university_id': universityId,
      'prize_info': prizeInfo,
      'requirements': requirements,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? shortDescription,
    String? fullDescription,
    String? category,
    List<String>? tags,
    String? bannerUrl,
    String? posterUrl,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? venue,
    int? participantLimit,
    DateTime? registrationDeadline,
    String? organizerUid,
    String? organizerName,
    String? conductedBy,
    String? contactNumbers,
    String? whatsappLink,
    String? participationLink,
    bool? providesAttendance,
    bool? requiresPayment,
    String? feeAmount,
    bool? providesCertificate,
    String? permissionLetterUrl,
    EventStatus? status,
    bool? isApproved,
    bool? isFeatured,
    int? participantCount,
    int? viewCount,
    int? shareCount,
    int? likeCount,
    String? universityId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? prizeInfo,
    String? requirements,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      posterUrl: posterUrl ?? this.posterUrl,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      venue: venue ?? this.venue,
      participantLimit: participantLimit ?? this.participantLimit,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      organizerUid: organizerUid ?? this.organizerUid,
      organizerName: organizerName ?? this.organizerName,
      conductedBy: conductedBy ?? this.conductedBy,
      contactNumbers: contactNumbers ?? this.contactNumbers,
      whatsappLink: whatsappLink ?? this.whatsappLink,
      participationLink: participationLink ?? this.participationLink,
      providesAttendance: providesAttendance ?? this.providesAttendance,
      requiresPayment: requiresPayment ?? this.requiresPayment,
      feeAmount: feeAmount ?? this.feeAmount,
      providesCertificate: providesCertificate ?? this.providesCertificate,
      permissionLetterUrl: permissionLetterUrl ?? this.permissionLetterUrl,
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      isFeatured: isFeatured ?? this.isFeatured,
      participantCount: participantCount ?? this.participantCount,
      viewCount: viewCount ?? this.viewCount,
      shareCount: shareCount ?? this.shareCount,
      likeCount: likeCount ?? this.likeCount,
      universityId: universityId ?? this.universityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      prizeInfo: prizeInfo ?? this.prizeInfo,
      requirements: requirements ?? this.requirements,
    );
  }

  /// Computed: whether registration deadline has passed.
  bool get isRegistrationClosed {
    if (registrationDeadline == null) return false;
    return DateTime.now().isAfter(registrationDeadline!);
  }

  /// Computed: whether event is full.
  bool get isFull {
    if (participantLimit <= 0) return false;
    return participantCount >= participantLimit;
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }
}

/// Registration record linking a user to an event.
class EventRegistration {
  final String? id;
  final String eventId;
  final String userId;
  final String userName;
  final String? ticketId;
  final bool checkedIn;
  final DateTime? registeredAt;

  const EventRegistration({
    this.id,
    required this.eventId,
    required this.userId,
    this.userName = '',
    this.ticketId,
    this.checkedIn = false,
    this.registeredAt,
  });

  factory EventRegistration.fromMap(Map<String, dynamic> map) {
    return EventRegistration(
      id: map['id'] as String?,
      eventId: (map['event_id'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? '',
      userName: (map['user_name'] as String?) ?? '',
      ticketId: map['ticket_id'] as String?,
      checkedIn: (map['checked_in'] as bool?) ?? false,
      registeredAt: map['registered_at'] != null
          ? DateTime.tryParse(map['registered_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'user_name': userName,
      'ticket_id': ticketId,
      'checked_in': checkedIn,
    };
  }
}

/// Certificate record for a completed event.
class EventCertificate {
  final String? id;
  final String eventId;
  final String eventTitle;
  final String userId;
  final String issuerName;
  final String? certificateUrl;
  final DateTime? issuedAt;

  const EventCertificate({
    this.id,
    required this.eventId,
    this.eventTitle = '',
    required this.userId,
    this.issuerName = '',
    this.certificateUrl,
    this.issuedAt,
  });

  factory EventCertificate.fromMap(Map<String, dynamic> map) {
    return EventCertificate(
      id: map['id'] as String?,
      eventId: (map['event_id'] as String?) ?? '',
      eventTitle: (map['event_title'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? '',
      issuerName: (map['issuer_name'] as String?) ?? '',
      certificateUrl: map['certificate_url'] as String?,
      issuedAt: map['issued_at'] != null
          ? DateTime.tryParse(map['issued_at'] as String)
          : null,
    );
  }

  bool get isAditya {
    return eventTitle.toLowerCase().contains('aditya') || 
           issuerName.toLowerCase().contains('aditya');
  }
}

/// Chat message in an event chat room.
class EventChatMessage {
  final String? id;
  final String eventId;
  final String userId;
  final String userName;
  final String message;
  final bool isOrganizer;
  final DateTime? createdAt;

  const EventChatMessage({
    this.id,
    required this.eventId,
    required this.userId,
    this.userName = '',
    required this.message,
    this.isOrganizer = false,
    this.createdAt,
  });

  factory EventChatMessage.fromMap(Map<String, dynamic> map) {
    return EventChatMessage(
      id: map['id'] as String?,
      eventId: (map['event_id'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? '',
      userName: (map['user_name'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      isOrganizer: (map['is_organizer'] as bool?) ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'user_name': userName,
      'message': message,
      'is_organizer': isOrganizer,
    };
  }
}
