import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/models/google_calendar_models.dart';
import 'package:utopia_app/services/google_calendar_service.dart';
import 'package:utopia_app/services/calendar_cache_service.dart';
import 'package:utopia_app/services/focus_database_service.dart';
import 'package:utopia_app/services/focus_supabase_service.dart';
import 'package:utopia_app/services/notification_service.dart';
import 'package:utopia_app/services/reminder_calendar_bridge.dart';

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key, this.event, this.initialDate});

  final GoogleCalendarEvent? event;
  final DateTime? initialDate;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  bool _addToReminders = false;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late TextEditingController _guestController;

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isAllDay = false;
  
  String? _selectedCalendarId;
  List<GoogleCalendar> _calendars = [];

  String? _selectedColorId;
  String _rrule = '';
  bool _generateMeet = false;
  String _visibility = 'default';

  List<EventAttendee> _attendees = [];
  List<EventAttachment> _attachments = [];
  
  bool _saving = false;

  final Map<String, Color> _googleColors = {
    '1': const Color(0xFF7986CB), // Lavender
    '2': const Color(0xFF33B679), // Sage
    '3': const Color(0xFF8E24AA), // Grape
    '4': const Color(0xFFE67C73), // Flamingo
    '5': const Color(0xFFF6BF26), // Banana
    '6': const Color(0xFFF4511E), // Tangerine
    '7': const Color(0xFF039BE5), // Peacock
    '8': const Color(0xFF616161), // Graphite
    '9': const Color(0xFF3F51B5), // Blueberry
    '10': const Color(0xFF0B8043), // Basil
    '11': const Color(0xFFD50000), // Tomato
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.summary ?? '');
    if (widget.event != null) {
      final hasReminder = ReminderCalendarBridge.instance.extractReminderIdFromEvent(widget.event!) != null;
      _addToReminders = hasReminder;
    }
    _descController = TextEditingController(text: widget.event?.description ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _guestController = TextEditingController();

    // Initial Date / Timings Setup
    final now = DateTime.now();
    final baseStart = widget.event?.startTime ?? widget.initialDate ?? DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    _startDate = baseStart;
    _endDate = widget.event?.endTime ?? _startDate.add(const Duration(hours: 1));
    _isAllDay = widget.event?.isAllDay ?? false;

    _selectedCalendarId = widget.event?.calendarId;
    _selectedColorId = widget.event?.colorId;
    _rrule = widget.event?.rrule ?? '';
    _generateMeet = widget.event?.hangoutLink != null;
    _visibility = widget.event?.visibility ?? 'default';

    _attendees = widget.event?.attendees != null ? List.from(widget.event!.attendees) : [];
    _attachments = widget.event?.attachments != null ? List.from(widget.event!.attachments) : [];

    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    final list = await CalendarCacheService.instance.getCalendars();
    // Only allow calendars where the user can write
    final writable = list.where((c) => c.accessRole == 'owner' || c.accessRole == 'writer').toList();
    setState(() {
      _calendars = writable;
      if (_selectedCalendarId == null && _calendars.isNotEmpty) {
        // default to primary or first available
        final primaryIndex = _calendars.indexWhere((c) => c.id == 'primary');
        _selectedCalendarId = primaryIndex != -1 ? _calendars[primaryIndex].id : _calendars.first.id;
      }

      // Safeguard against DropdownButtonFormField value mismatch assertion crashes
      if (_selectedCalendarId != null && _calendars.isNotEmpty && !_calendars.any((c) => c.id == _selectedCalendarId)) {
        if (_selectedCalendarId == 'primary') {
          final emailIndex = _calendars.indexWhere((c) => c.id.contains('@'));
          if (emailIndex != -1) {
            _selectedCalendarId = _calendars[emailIndex].id;
          } else {
            _selectedCalendarId = _calendars.first.id;
          }
        } else {
          final primaryIndex = _calendars.indexWhere((c) => c.id == 'primary');
          _selectedCalendarId = primaryIndex != -1 ? _calendars[primaryIndex].id : _calendars.first.id;
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _guestController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime initialDate = isStart ? _startDate : _endDate;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: U.primary,
              onPrimary: U.bg,
              surface: U.card,
              onSurface: U.text,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: U.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (_isAllDay) {
        setState(() {
          if (isStart) {
            _startDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
            if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate.add(const Duration(days: 1));
            }
          } else {
            _endDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
            if (_endDate.isBefore(_startDate)) {
              _startDate = _endDate.subtract(const Duration(days: 1));
            }
          }
        });
      } else {
        if (!mounted) return;
        final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: initialTime,
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: U.primary,
                  onPrimary: U.bg,
                  surface: U.card,
                  onSurface: U.text,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: U.primary,
                  ),
                ),
              ),
              child: child!,
            );
          },
        );

        if (pickedTime != null) {
          final resolvedDt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          setState(() {
            if (isStart) {
              _startDate = resolvedDt;
              if (_endDate.isBefore(_startDate)) {
                _endDate = _startDate.add(const Duration(hours: 1));
              }
            } else {
              _endDate = resolvedDt;
              if (_endDate.isBefore(_startDate)) {
                _startDate = _endDate.subtract(const Duration(hours: 1));
              }
            }
          });
        }
      }
    }
  }

  void _addAttendee() {
    final email = _guestController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      U.showSnackBar(context, 'Please enter a valid guest email', icon: Icons.warning_amber_rounded);
      return;
    }

    if (_attendees.any((a) => a.email == email)) {
      U.showSnackBar(context, 'Guest already added', icon: Icons.info_outline);
      return;
    }

    setState(() {
      _attendees.add(EventAttendee(email: email, responseStatus: 'needsAction'));
      _guestController.clear();
    });
  }

  void _removeAttendee(int index) {
    setState(() {
      _attendees.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCalendarId == null) {
      return;
    }

    setState(() => _saving = true);

    final eventId = widget.event?.id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
    
    String finalDescription = _descController.text.trim();
    String? reminderIdToCreate;

    if (_addToReminders) {
      final existingId = widget.event != null
          ? ReminderCalendarBridge.instance.extractReminderIdFromEvent(widget.event!)
          : null;
      final reminderId = existingId ?? const Uuid().v4();
      
      if (!finalDescription.contains('[utopia_reminder:')) {
        finalDescription = '[utopia_reminder:$reminderId]\n$finalDescription';
      }
      reminderIdToCreate = reminderId;
    } else {
      finalDescription = finalDescription.replaceAll(RegExp(r'\[utopia_reminder:[a-zA-Z0-9\-]+\]\n?'), '');
      
      if (widget.event != null) {
        final oldId = ReminderCalendarBridge.instance.extractReminderIdFromEvent(widget.event!);
        if (oldId != null) {
          await FocusDatabaseService().deleteReminder(oldId);
          await NotificationService.cancelFocusReminder(oldId);
          final supabaseService = FocusSupabaseService();
          if (supabaseService.isInitialized) {
            await supabaseService.deleteReminder(oldId);
          }
        }
      }
    }

    final event = GoogleCalendarEvent(
      id: eventId,
      calendarId: _selectedCalendarId!,
      summary: _titleController.text.trim().isEmpty ? 'Untitled Event' : _titleController.text.trim(),
      description: finalDescription,
      location: _locationController.text.trim(),
      startTime: _startDate,
      endTime: _endDate,
      isAllDay: _isAllDay,
      timezone: DateTime.now().timeZoneName,
      rrule: _rrule.isEmpty ? null : _rrule,
      colorId: _selectedColorId,
      visibility: _visibility,
      attendees: _attendees,
      reminders: const [],
      attachments: _attachments,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    bool success;
    if (widget.event == null) {
      success = await GoogleCalendarService.instance.createEvent(event, generateMeet: _generateMeet);
    } else {
      success = await GoogleCalendarService.instance.updateEvent(event, generateMeet: _generateMeet);
    }

    if (success && reminderIdToCreate != null) {
      final savedEvent = await CalendarCacheService.instance.getEvent(eventId);
      if (savedEvent != null) {
        await ReminderCalendarBridge.instance.createReminderFromEvent(savedEvent);
      }
    }

    setState(() => _saving = false);

    if (success && mounted) {
      U.showSnackBar(
        context,
        widget.event == null ? 'Event created successfully!' : 'Event updated successfully!',
        icon: Icons.check_circle_outline,
      );
      Navigator.pop(context, true);
    } else {
      if (mounted) {
        U.showSnackBar(context, 'Failed to save event. Event cached locally.', icon: Icons.warning);
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.event == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: U.border, width: 0.5),
        ),
        title: Text(
          'Delete Event',
          style: GoogleFonts.plusJakartaSans(color: U.red, fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: U.sub)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: U.red),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _saving = true);
      final proceed = await ReminderCalendarBridge.instance.onCalendarEventDeleted(context, widget.event!);
      if (!proceed) {
        setState(() => _saving = false);
        return;
      }
      final success = await GoogleCalendarService.instance.deleteEvent(widget.event!);
      setState(() => _saving = false);
      if (success && mounted) {
        U.showSnackBar(context, 'Event deleted successfully!', icon: Icons.delete_outline);
        Navigator.pop(context, true);
      } else {
        if (mounted) U.showSnackBar(context, 'Failed to delete event locally', icon: Icons.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        title: Text(
          widget.event == null ? 'Create Event' : 'Edit Event',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            fontSize: 24,
          ),
        ),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: U.red),
              onPressed: _saving ? null : _delete,
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.check, color: U.primary),
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Event Title
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'Enter title of your event',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter event descriptions, links, notes',
                ),
              ),
              const SizedBox(height: 20),

              // Location
              TextFormField(
                controller: _locationController,
                style: GoogleFonts.plusJakartaSans(),
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Enter meeting room, address, physical location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Calendar Dropdown Selection
              if (_calendars.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedCalendarId,
                  style: GoogleFonts.plusJakartaSans(color: U.text),
                  dropdownColor: U.card,
                  decoration: const InputDecoration(
                    labelText: 'Calendar',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  items: _calendars.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.summary),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCalendarId = val);
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Timings Layout
              Card(
                color: U.card,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // All Day Toggle
                      SwitchListTile(
                        title: Text('All-day event', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500)),
                        value: _isAllDay,
                        activeColor: U.primary,
                        onChanged: (val) {
                          setState(() {
                            _isAllDay = val;
                          });
                        },
                      ),
                      const Divider(),

                      // Start Date Time
                      ListTile(
                        title: Text('Start', style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 13)),
                        trailing: Text(
                          _isAllDay
                              ? dateFormat.format(_startDate)
                              : '${dateFormat.format(_startDate)}  ${timeFormat.format(_startDate)}',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: U.text),
                        ),
                        onTap: () => _selectDate(context, true),
                      ),
                      const Divider(),

                      // End Date Time
                      ListTile(
                        title: Text('End', style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 13)),
                        trailing: Text(
                          _isAllDay
                              ? dateFormat.format(_endDate)
                              : '${dateFormat.format(_endDate)}  ${timeFormat.format(_endDate)}',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: U.text),
                        ),
                        onTap: () => _selectDate(context, false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recurrence Rule Dropdown
              DropdownButtonFormField<String>(
                value: _rrule,
                style: GoogleFonts.plusJakartaSans(color: U.text),
                dropdownColor: U.card,
                decoration: const InputDecoration(
                  labelText: 'Recurrence',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text('Does not repeat', style: GoogleFonts.plusJakartaSans())),
                  DropdownMenuItem(value: 'FREQ=DAILY', child: Text('Daily', style: GoogleFonts.plusJakartaSans())),
                  DropdownMenuItem(value: 'FREQ=WEEKLY', child: Text('Weekly', style: GoogleFonts.plusJakartaSans())),
                  DropdownMenuItem(value: 'FREQ=MONTHLY', child: Text('Monthly', style: GoogleFonts.plusJakartaSans())),
                  DropdownMenuItem(value: 'FREQ=YEARLY', child: Text('Yearly', style: GoogleFonts.plusJakartaSans())),
                ],
                onChanged: (val) {
                  setState(() => _rrule = val ?? '');
                },
              ),
              const SizedBox(height: 24),

              // Event Color Swatches
              Text(
                'Event Color',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: U.sub, fontSize: 13),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedColorId = null),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: U.gold,
                          border: _selectedColorId == null
                              ? Border.all(color: U.primary, width: 2.5)
                              : null,
                        ),
                        child: _selectedColorId == null
                            ? Icon(Icons.check, size: 14, color: U.bg)
                            : null,
                      ),
                    ),
                    ..._googleColors.entries.map((entry) {
                      final selected = _selectedColorId == entry.key;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorId = entry.key),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: entry.value,
                            border: selected
                                ? Border.all(color: U.primary, width: 2.5)
                                : null,
                          ),
                          child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Google Meet Toggle
              Card(
                color: U.card,
                child: SwitchListTile(
                  title: Text(
                    'Generate Google Meet link',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Add a video conference room to the event',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: U.sub),
                  ),
                  value: _generateMeet,
                  activeColor: U.primary,
                  onChanged: (val) {
                    setState(() => _generateMeet = val);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Visibility Dropdown
              DropdownButtonFormField<String>(
                value: _visibility,
                style: GoogleFonts.plusJakartaSans(color: U.text),
                dropdownColor: U.card,
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                  prefixIcon: Icon(Icons.visibility),
                ),
                items: [
                  DropdownMenuItem(value: 'default', child: Text('Default Visibility', style: GoogleFonts.plusJakartaSans())),
                  DropdownMenuItem(value: 'public', child: Text('Public', style: GoogleFonts.plusJakartaSans())),
                  DropdownMenuItem(value: 'private', child: Text('Private', style: GoogleFonts.plusJakartaSans())),
                ],
                onChanged: (val) {
                  setState(() => _visibility = val ?? 'default');
                },
              ),
              const SizedBox(height: 24),

              // Add to Reminders Switch
              Card(
                color: U.card,
                child: SwitchListTile(
                  title: Text(
                    'Add to Reminders',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Mirror this event as a one-time reminder in UTOPIA',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: U.sub),
                  ),
                  value: _addToReminders,
                  activeColor: U.primary,
                  onChanged: (val) {
                    setState(() => _addToReminders = val);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Dynamic Guest/Attendees Invitation
              Card(
                color: U.card,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite Guests', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _guestController,
                              style: GoogleFonts.plusJakartaSans(),
                              decoration: const InputDecoration(
                                hintText: 'guest@email.com',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _addAttendee,
                            style: FilledButton.styleFrom(
                              backgroundColor: U.primary,
                              foregroundColor: U.bg,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_attendees.isEmpty)
                        Text(
                          'No guests invited yet.',
                          style: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 11),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _attendees.length,
                          itemBuilder: (ctx, index) {
                            final att = _attendees[index];
                            return ListTile(
                              title: Text(att.email ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: U.red),
                                onPressed: () => _removeAttendee(index),
                              ),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
