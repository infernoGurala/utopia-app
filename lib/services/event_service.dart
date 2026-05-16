import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:uuid/uuid.dart';
import '../models/event_model.dart';

/// Service for managing events via Supabase.
class EventService {
  static final EventService instance = EventService._();
  EventService._();

  final Set<String> _viewedEvents = {};

  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Event CRUD ────────────────────────────────────────────────

  /// Create a new event. Returns the created event ID.
  Future<String?> createEvent(EventModel event) async {
    try {
      final data = event.toMap();
      data.remove('id'); // let Supabase generate the UUID
      final response = await _sb.from('events').insert(data).select('id').single();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('Failed to create event: $e');
      throw Exception('Failed to publish event: $e');
    }
  }

  /// Update an existing event.
  Future<bool> updateEvent(String eventId, Map<String, dynamic> fields) async {
    try {
      fields['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _sb.from('events').update(fields).eq('id', eventId);
      return true;
    } catch (e) {
      debugPrint('Failed to update event: $e');
      return false;
    }
  }

  /// Delete an event and all related data.
  Future<bool> deleteEvent(String eventId) async {
    try {
      await _sb.from('event_registrations').delete().eq('event_id', eventId);
      await _sb.from('event_chats').delete().eq('event_id', eventId);
      await _sb.from('event_likes').delete().eq('event_id', eventId);
      await _sb.from('event_certificates').delete().eq('event_id', eventId);
      await _sb.from('events').delete().eq('id', eventId);
      return true;
    } catch (e) {
      debugPrint('Failed to delete event: $e');
      return false;
    }
  }

  // ─── Event Queries ─────────────────────────────────────────────

  /// Get all approved events, optionally filtered.
  Future<List<EventModel>> getEvents({
    String? category,
    String? status,
    String? search,
    int limit = 50,
  }) async {
    try {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toIso8601String().split('T').first;
      
      var query = _sb
          .from('events')
          .select()
          .eq('is_approved', true)
          .gte('date', twoDaysAgo);

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final events = List<Map<String, dynamic>>.from(response)
          .map((m) => EventModel.fromMap(m))
          .toList();

      if (search != null && search.isNotEmpty) {
        final lowerSearch = search.toLowerCase();
        return events.where((e) =>
            e.title.toLowerCase().contains(lowerSearch) ||
            e.shortDescription.toLowerCase().contains(lowerSearch) ||
            e.tags.any((t) => t.toLowerCase().contains(lowerSearch))
        ).toList();
      }
      return events;
    } catch (e) {
      debugPrint('Failed to get events: $e');
      return [];
    }
  }

  /// Get trending events (highest combined views + likes).
  Future<List<EventModel>> getTrendingEvents({int limit = 10}) async {
    try {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toIso8601String().split('T').first;
      final response = await _sb
          .from('events')
          .select()
          .eq('is_approved', true)
          .gte('date', twoDaysAgo)
          .neq('status', 'cancelled')
          .order('view_count', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventModel.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get trending events: $e');
      return [];
    }
  }

  /// Get upcoming events (date > now, sorted by date ascending).
  Future<List<EventModel>> getUpcomingEvents({int limit = 10}) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _sb
          .from('events')
          .select()
          .eq('is_approved', true)
          .gte('date', today)
          .neq('status', 'cancelled')
          .order('date', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventModel.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get upcoming events: $e');
      return [];
    }
  }

  /// Get events that are currently live.
  Future<List<EventModel>> getLiveEvents({int limit = 10}) async {
    try {
      final response = await _sb
          .from('events')
          .select()
          .eq('is_approved', true)
          .eq('status', 'live_now')
          .limit(limit);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventModel.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get live events: $e');
      return [];
    }
  }

  /// Get events whose registration deadline is within the next 48 hours.
  Future<List<EventModel>> getEndingSoonEvents({int limit = 10}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final soon = DateTime.now().add(const Duration(hours: 48)).toUtc().toIso8601String();
      final response = await _sb
          .from('events')
          .select()
          .eq('is_approved', true)
          .gte('registration_deadline', now)
          .lte('registration_deadline', soon)
          .order('registration_deadline', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventModel.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get ending-soon events: $e');
      return [];
    }
  }

  /// Get a single event by ID.
  Future<EventModel?> getEvent(String eventId) async {
    try {
      final response = await _sb
          .from('events')
          .select()
          .eq('id', eventId)
          .maybeSingle();
      if (response == null) return null;
      return EventModel.fromMap(response);
    } catch (e) {
      debugPrint('Failed to get event $eventId: $e');
      return null;
    }
  }

  /// Increment view count for an event.
  Future<void> incrementViews(String eventId) async {
    if (_viewedEvents.contains(eventId)) return;
    _viewedEvents.add(eventId);
    
    try {
      await _sb.rpc('increment_event_views', params: {'event_id_param': eventId});
    } catch (e) {
      // Fallback: fetch and update
      try {
        final event = await getEvent(eventId);
        if (event != null) {
          await _sb.from('events')
              .update({'view_count': event.viewCount + 1})
              .eq('id', eventId);
        }
      } catch (_) {}
    }
  }

  // ─── Registration ──────────────────────────────────────────────

  /// Register current user for an event.
  Future<EventRegistration?> registerForEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final ticketId = 'UTOPIA-${const Uuid().v4().substring(0, 8).toUpperCase()}';

      final data = {
        'event_id': eventId,
        'user_id': uid,
        'user_name': user?.displayName ?? 'User',
        'ticket_id': ticketId,
        'checked_in': false,
      };

      final response = await _sb.from('event_registrations').insert(data).select().single();

      // Update participant count
      await _sb.rpc('increment_event_participants', params: {'event_id_param': eventId}).catchError((_) async {
        final event = await getEvent(eventId);
        if (event != null) {
          await _sb.from('events')
              .update({'participant_count': event.participantCount + 1})
              .eq('id', eventId);
        }
      });

      return EventRegistration.fromMap(response);
    } catch (e) {
      debugPrint('Failed to register for event: $e');
      return null;
    }
  }

  /// Unregister current user from an event.
  Future<bool> unregisterFromEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _sb.from('event_registrations')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', uid);

      // Decrement participant count
      final event = await getEvent(eventId);
      if (event != null && event.participantCount > 0) {
        await _sb.from('events')
            .update({'participant_count': event.participantCount - 1})
            .eq('id', eventId);
      }
      return true;
    } catch (e) {
      debugPrint('Failed to unregister from event: $e');
      return false;
    }
  }

  /// Check if current user is registered for an event.
  Future<bool> isRegistered(String eventId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final response = await _sb.from('event_registrations')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', uid)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get the registration record for the current user.
  Future<EventRegistration?> getMyRegistration(String eventId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final response = await _sb.from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', uid)
          .maybeSingle();
      if (response == null) return null;
      return EventRegistration.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Get all registrations for an event.
  Future<List<EventRegistration>> getRegistrations(String eventId) async {
    try {
      final response = await _sb.from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .order('registered_at', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventRegistration.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get registrations: $e');
      return [];
    }
  }

  // ─── Likes / Saves ────────────────────────────────────────────

  /// Like/save an event.
  Future<bool> likeEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _sb.from('event_likes').insert({
        'event_id': eventId,
        'user_id': uid,
      });
      return true;
    } catch (e) {
      debugPrint('Failed to like event: $e');
      return false;
    }
  }

  /// Unlike/unsave an event.
  Future<bool> unlikeEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _sb.from('event_likes')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('Failed to unlike event: $e');
      return false;
    }
  }

  /// Check if current user has liked an event.
  Future<bool> isLiked(String eventId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final response = await _sb.from('event_likes')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', uid)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  // ─── Chat ──────────────────────────────────────────────────────

  /// Send a chat message in an event.
  Future<bool> sendChatMessage(String eventId, String message) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      // Check if user is the organizer
      final event = await getEvent(eventId);
      final isOrg = event?.organizerUid == uid;

      await _sb.from('event_chats').insert({
        'event_id': eventId,
        'user_id': uid,
        'user_name': user?.displayName ?? 'User',
        'message': message,
        'is_organizer': isOrg,
      });
      return true;
    } catch (e) {
      debugPrint('Failed to send chat message: $e');
      return false;
    }
  }

  /// Stream chat messages for an event (real-time).
  Stream<List<EventChatMessage>> streamChat(String eventId) {
    return _sb
        .from('event_chats')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((m) => EventChatMessage.fromMap(m)).toList());
  }

  // ─── Organizer ─────────────────────────────────────────────────

  /// Get events created by a specific organizer.
  Future<List<EventModel>> getEventsByOrganizer(String uid) async {
    try {
      final response = await _sb
          .from('events')
          .select()
          .eq('organizer_uid', uid)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventModel.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get organizer events: $e');
      return [];
    }
  }

  /// Get aggregated analytics for an organizer.
  Future<Map<String, dynamic>> getOrganizerAnalytics(String uid) async {
    try {
      final events = await getEventsByOrganizer(uid);
      int totalRegs = 0;
      int totalViews = 0;
      int totalShares = 0;
      int totalLikes = 0;
      for (final e in events) {
        totalRegs += e.participantCount;
        totalViews += e.viewCount;
        totalShares += e.shareCount;
        totalLikes += e.likeCount;
      }
      final attendanceRatio = totalRegs > 0
          ? ((totalRegs / (events.length * 100).clamp(1, double.infinity)) * 100).round()
          : 0;
      return {
        'total_registrations': totalRegs,
        'total_views': totalViews,
        'total_shares': totalShares,
        'total_likes': totalLikes,
        'event_count': events.length,
        'engagement': '${attendanceRatio.clamp(0, 100)}%',
      };
    } catch (e) {
      debugPrint('Failed to get organizer analytics: $e');
      return {};
    }
  }

  // ─── Admin ─────────────────────────────────────────────────────

  /// Get events pending approval.
  Future<List<EventModel>> getPendingEvents() async {
    try {
      final response = await _sb
          .from('events')
          .select()
          .eq('is_approved', false)
          .neq('status', 'cancelled')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventModel.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get pending events: $e');
      return [];
    }
  }

  /// Approve an event.
  Future<bool> approveEvent(String eventId) async {
    return updateEvent(eventId, {'is_approved': true, 'status': 'registration_open'});
  }

  /// Reject an event.
  Future<bool> rejectEvent(String eventId) async {
    return updateEvent(eventId, {'status': 'cancelled'});
  }

  /// Toggle featured status.
  Future<bool> toggleFeatured(String eventId, bool featured) async {
    return updateEvent(eventId, {'is_featured': featured});
  }

  // ─── Certificates ──────────────────────────────────────────────

  /// Get certificates for current user.
  Future<List<EventCertificate>> getMyCertificates() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final response = await _sb
          .from('event_certificates')
          .select()
          .eq('user_id', uid)
          .order('issued_at', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map((m) => EventCertificate.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('Failed to get certificates: $e');
      return [];
    }
  }

  /// Issue a certificate to a user.
  Future<bool> issueCertificate({
    required String eventId,
    required String eventTitle,
    required String userId,
    required String issuerName,
    String? certificateUrl,
  }) async {
    try {
      await _sb.from('event_certificates').insert({
        'event_id': eventId,
        'event_title': eventTitle,
        'user_id': userId,
        'issuer_name': issuerName,
        'certificate_url': certificateUrl,
      });
      return true;
    } catch (e) {
      debugPrint('Failed to issue certificate: $e');
      return false;
    }
  }
}
