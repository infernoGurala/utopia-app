import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class EventNotificationsScreen extends StatefulWidget {
  const EventNotificationsScreen({super.key});

  @override
  State<EventNotificationsScreen> createState() => _EventNotificationsScreenState();
}

class _EventNotificationsScreenState extends State<EventNotificationsScreen> {
  List<EventModel> _endingSoon = [];
  List<EventModel> _newEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        EventService.instance.getEndingSoonEvents(limit: 5),
        EventService.instance.getUpcomingEvents(limit: 5),
      ]);
      if (mounted) {
        setState(() {
          _endingSoon = results[0];
          _newEvents = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(color: U.text, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: UtopiaLoader(scale: 0.7))
          : RefreshIndicator(
              color: U.primary,
              onRefresh: _loadNotifications,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                children: [
                  if (_endingSoon.isNotEmpty) ...[
                    ..._endingSoon.map((event) => _buildNotificationItem(
                      'Registration Ending Soon',
                      '${event.title} registration closes on ${_formatDate(event.registrationDeadline ?? event.date)}.',
                      Icons.warning_amber_rounded,
                      U.peach,
                      isUnread: true,
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0)),
                  ],
                  if (_newEvents.isNotEmpty) ...[
                    ..._newEvents.map((event) => _buildNotificationItem(
                      'New Event',
                      '${event.title} was just added by ${event.conductedBy.isNotEmpty ? event.conductedBy : event.organizerName}.',
                      Icons.event_available_rounded,
                      U.primary,
                      isUnread: false,
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0)),
                  ],
                  if (_endingSoon.isEmpty && _newEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 48, color: U.dim),
                            const SizedBox(height: 12),
                            Text('No notifications', style: GoogleFonts.outfit(fontSize: 16, color: U.sub)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationItem(String title, String body, IconData icon, Color color, {required bool isUnread}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? color.withValues(alpha: 0.05) : U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnread ? color.withValues(alpha: 0.3) : U.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                    color: U.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isUnread ? U.text.withValues(alpha: 0.9) : U.sub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
