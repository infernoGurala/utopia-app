import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/models/google_calendar_models.dart';
import 'package:utopia_app/services/calendar_cache_service.dart';
import 'package:utopia_app/services/google_calendar_service.dart';

class CalendarManageDrawer extends StatefulWidget {
  const CalendarManageDrawer({super.key, required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<CalendarManageDrawer> createState() => _CalendarManageDrawerState();
}

class _CalendarManageDrawerState extends State<CalendarManageDrawer> {
  List<GoogleCalendar> _calendars = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    setState(() => _loading = true);
    try {
      final list = await CalendarCacheService.instance.getCalendars();
      setState(() {
        _calendars = list;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggleCalendar(GoogleCalendar cal, bool selected) async {
    await CalendarCacheService.instance.updateCalendarSelected(cal.id, selected);
    await _loadCalendars();
    widget.onRefresh();
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    U.showSnackBar(context, 'Syncing with Google Calendar...', icon: Icons.sync);
    await GoogleCalendarService.instance.syncAll();
    await _loadCalendars();
    widget.onRefresh();
    setState(() => _loading = false);
    if (mounted) {
      U.showSnackBar(context, 'Sync completed successfully!', icon: Icons.check_circle_outline);
    }
  }

  Future<void> _disconnectAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: U.border, width: 0.5),
        ),
        title: Text(
          'Disconnect Google Calendar',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to disconnect your Google Account? All cached calendar events will be cleared locally.',
          style: GoogleFonts.plusJakartaSans(color: U.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: U.sub)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: U.red),
            child: Text('Disconnect', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      await GoogleCalendarService.instance.disconnect();
      widget.onRefresh();
      if (mounted) {
        Navigator.pop(context);
        U.showSnackBar(context, 'Google Calendar disconnected', icon: Icons.link_off);
      }
    }
  }

  Future<void> _createCalendar() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: U.border, width: 0.5),
        ),
        title: Text(
          'New Calendar',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Calendar Name',
              ),
              style: GoogleFonts.plusJakartaSans(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                hintText: 'Description (Optional)',
              ),
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: U.sub)),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: U.primary, foregroundColor: U.bg),
            child: Text('Create', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      final success = await GoogleCalendarService.instance.createCalendar(
        nameController.text.trim(),
        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
      );
      if (success) {
        await _loadCalendars();
        widget.onRefresh();
        if (mounted) U.showSnackBar(context, 'Calendar created successfully!');
      } else {
        if (mounted) U.showSnackBar(context, 'Failed to create calendar', icon: Icons.error);
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _renameCalendar(GoogleCalendar cal) async {
    final controller = TextEditingController(text: cal.summary);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: U.border, width: 0.5),
        ),
        title: Text(
          'Rename Calendar',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Calendar Name'),
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: U.sub)),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: U.primary, foregroundColor: U.bg),
            child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      final success = await GoogleCalendarService.instance.updateCalendar(
        cal.id,
        controller.text.trim(),
      );
      if (success) {
        await _loadCalendars();
        widget.onRefresh();
        if (mounted) U.showSnackBar(context, 'Calendar renamed!');
      } else {
        if (mounted) U.showSnackBar(context, 'Failed to rename calendar', icon: Icons.error);
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteCalendar(GoogleCalendar cal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: U.border, width: 0.5),
        ),
        title: Text(
          'Delete Calendar',
          style: GoogleFonts.plusJakartaSans(color: U.red, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete calendar "${cal.summary}"? This action will permanently remove it from your Google account.',
          style: GoogleFonts.plusJakartaSans(color: U.sub),
        ),
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
      setState(() => _loading = true);
      final success = await GoogleCalendarService.instance.deleteCalendar(cal.id);
      if (success) {
        await _loadCalendars();
        widget.onRefresh();
        if (mounted) U.showSnackBar(context, 'Calendar deleted permanently');
      } else {
        if (mounted) U.showSnackBar(context, 'Failed to delete calendar', icon: Icons.error);
      }
      setState(() => _loading = false);
    }
  }

  Color _getCalendarColor(String? colorStr) {
    if (colorStr == null) return U.gold;
    final hex = colorStr.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return U.gold;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.value.isDark;

    return Container(
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: U.border, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: U.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Calendars',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: U.text,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.sync_rounded, color: U.primary),
                      onPressed: _loading ? null : _syncNow,
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline_rounded, color: U.primary),
                      onPressed: _loading ? null : _createCalendar,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_calendars.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No calendars found.',
                    style: GoogleFonts.plusJakartaSans(color: U.dim),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _calendars.length,
                  itemBuilder: (context, index) {
                    final cal = _calendars[index];
                    final calColor = _getCalendarColor(cal.backgroundColor);
                    final isOwner = cal.accessRole == 'owner' || cal.accessRole == 'writer';
                    
                    return Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: calColor.withValues(alpha: 0.5),
                      ),
                      child: CheckboxListTile(
                        value: cal.selected,
                        activeColor: calColor,
                        checkColor: isDark ? Colors.black : Colors.white,
                        title: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: calColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cal.summary,
                                style: GoogleFonts.plusJakartaSans(
                                  color: U.text,
                                  fontWeight: cal.id == 'primary' ? FontWeight.w600 : FontWeight.w400,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: cal.description != null && cal.description!.isNotEmpty
                            ? Text(
                                cal.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 11),
                              )
                            : null,
                        secondary: isOwner && cal.id != 'primary'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, size: 18, color: U.dim),
                                    onPressed: () => _renameCalendar(cal),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 18, color: U.red.withValues(alpha: 0.7)),
                                    onPressed: () => _deleteCalendar(cal),
                                  ),
                                ],
                              )
                            : null,
                        onChanged: (val) {
                          if (val != null) _toggleCalendar(cal, val);
                        },
                      ),
                    );
                  },
                ),
              ),
            const Divider(height: 32),
            Center(
              child: TextButton.icon(
                onPressed: _loading ? null : _disconnectAccount,
                icon: Icon(Icons.link_off_rounded, color: U.red, size: 18),
                label: Text(
                  'Disconnect Account',
                  style: GoogleFonts.plusJakartaSans(
                    color: U.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
