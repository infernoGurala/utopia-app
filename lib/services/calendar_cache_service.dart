import 'package:sqflite/sqflite.dart';
import 'cache_service.dart';
import '../models/google_calendar_models.dart';

class CalendarCacheService {
  static final CalendarCacheService instance = CalendarCacheService._();
  CalendarCacheService._();

  Future<Database> get _db => CacheService().db;

  // ─── Calendar Cache Operations ───────────────────────────────

  Future<void> saveCalendars(List<GoogleCalendar> calendars) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final cal in calendars) {
        // Keep the local selection status if the calendar already exists
        final existing = await txn.query(
          'google_calendars',
          columns: ['selected'],
          where: 'id = ?',
          whereArgs: [cal.id],
          limit: 1,
        );

        int selectedVal = cal.selected ? 1 : 0;
        if (existing.isNotEmpty) {
          selectedVal = existing.first['selected'] as int;
        }

        await txn.insert(
          'google_calendars',
          {
            'id': cal.id,
            'summary': cal.summary,
            'description': cal.description,
            'background_color': cal.backgroundColor,
            'foreground_color': cal.foregroundColor,
            'selected': selectedVal,
            'access_role': cal.accessRole,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<GoogleCalendar>> getCalendars() async {
    final db = await _db;
    final rows = await db.query('google_calendars');
    return rows.map((r) => GoogleCalendar.fromMap(r)).toList();
  }

  Future<void> updateCalendarSelected(String id, bool selected) async {
    final db = await _db;
    await db.update(
      'google_calendars',
      {'selected': selected ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCalendar(String id) async {
    final db = await _db;
    await db.delete('google_calendars', where: 'id = ?', whereArgs: [id]);
    await db.delete('google_calendar_events', where: 'calendar_id = ?', whereArgs: [id]);
  }

  // ─── Event Cache Operations ──────────────────────────────────

  Future<void> saveEvents(List<GoogleCalendarEvent> events) async {
    final db = await _db;
    final batch = db.batch();
    for (final event in events) {
      batch.insert(
        'google_calendar_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveEvent(GoogleCalendarEvent event) async {
    final db = await _db;
    await db.insert(
      'google_calendar_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GoogleCalendarEvent?> getEvent(String id) async {
    final db = await _db;
    final rows = await db.query(
      'google_calendar_events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GoogleCalendarEvent.fromMap(rows.first);
  }

  Future<void> deleteEventLocally(String id) async {
    final db = await _db;
    final event = await getEvent(id);
    if (event == null) return;

    if (id.startsWith('local_')) {
      // Hard delete local unsynced events
      await db.delete(
        'google_calendar_events',
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // Soft delete events synced with the backend
      await db.update(
        'google_calendar_events',
        {
          'is_deleted': 1,
          'is_dirty': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> hardDeleteEvent(String id) async {
    final db = await _db;
    await db.delete(
      'google_calendar_events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<GoogleCalendarEvent>> getEvents({
    DateTime? start,
    DateTime? end,
    bool includeHidden = false,
  }) async {
    final db = await _db;
    
    String whereClause = 'e.is_deleted = 0';
    List<dynamic> whereArgs = [];

    if (!includeHidden) {
      whereClause += ' AND (c.selected = 1 OR c.selected IS NULL)';
    }

    final rows = await db.rawQuery('''
      SELECT e.* FROM google_calendar_events e
      LEFT JOIN google_calendars c ON e.calendar_id = c.id
      WHERE $whereClause
      ORDER BY e.start_time ASC
    ''', whereArgs);

    final events = rows.map((r) => GoogleCalendarEvent.fromMap(r)).toList();

    // Perform date filtering in memory due to SQLite date complexity (ISO8601 strings)
    return events.where((e) {
      if (e.startTime == null) return false;
      if (start != null && e.startTime!.isBefore(start)) return false;
      if (end != null && e.startTime!.isAfter(end)) return false;
      return true;
    }).toList();
  }

  Future<List<GoogleCalendarEvent>> getDirtyEvents() async {
    final db = await _db;
    final rows = await db.query(
      'google_calendar_events',
      where: 'is_dirty = 1 AND is_deleted = 0',
    );
    return rows.map((r) => GoogleCalendarEvent.fromMap(r)).toList();
  }

  Future<List<GoogleCalendarEvent>> getDeletedEvents() async {
    final db = await _db;
    final rows = await db.query(
      'google_calendar_events',
      where: 'is_dirty = 1 AND is_deleted = 1',
    );
    return rows.map((r) => GoogleCalendarEvent.fromMap(r)).toList();
  }

  Future<List<GoogleCalendarEvent>> searchEvents(String query) async {
    final db = await _db;
    final sqlQuery = '%${query.toLowerCase()}%';

    final rows = await db.rawQuery('''
      SELECT e.* FROM google_calendar_events e
      LEFT JOIN google_calendars c ON e.calendar_id = c.id
      WHERE e.is_deleted = 0 
        AND (c.selected = 1 OR c.selected IS NULL)
        AND (
          LOWER(e.summary) LIKE ? 
          OR LOWER(e.description) LIKE ? 
          OR LOWER(e.location) LIKE ?
        )
      ORDER BY e.start_time ASC
    ''', [sqlQuery, sqlQuery, sqlQuery]);

    return rows.map((r) => GoogleCalendarEvent.fromMap(r)).toList();
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('google_calendars');
    await db.delete('google_calendar_events');
  }
}
