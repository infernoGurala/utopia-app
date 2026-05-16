import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class AdminEventsPanel extends StatefulWidget {
  const AdminEventsPanel({super.key});

  @override
  State<AdminEventsPanel> createState() => _AdminEventsPanelState();
}

class _AdminEventsPanelState extends State<AdminEventsPanel> {
  List<EventModel> _pendingEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final events = await EventService.instance.getPendingEvents();
      if (mounted) {
        setState(() {
          _pendingEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveEvent(EventModel event) async {
    if (event.id == null) return;
    final success = await EventService.instance.approveEvent(event.id!);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${event.title} approved!', style: GoogleFonts.outfit()), backgroundColor: U.teal),
      );
      _loadData();
    }
  }

  Future<void> _rejectEvent(EventModel event) async {
    if (event.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject Event?', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        content: Text('This will mark "${event.title}" as cancelled.', style: GoogleFonts.outfit(color: U.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Reject', style: GoogleFonts.outfit(color: U.red))),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await EventService.instance.rejectEvent(event.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${event.title} rejected', style: GoogleFonts.outfit()), backgroundColor: U.red),
        );
        _loadData();
      }
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
          'Admin Moderation Panel',
          style: GoogleFonts.outfit(color: U.text, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: U.primary))
          : RefreshIndicator(
              color: U.primary,
              onRefresh: _loadData,
              child: _pendingEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 64, color: U.teal),
                          const SizedBox(height: 16),
                          Text('All caught up!', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: U.text)),
                          const SizedBox(height: 4),
                          Text('No events pending approval', style: GoogleFonts.outfit(fontSize: 14, color: U.sub)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Event Approval Queue',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: U.peach.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_pendingEvents.length}',
                                  style: GoogleFonts.outfit(color: U.peach, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._pendingEvents.map((event) => _buildApprovalItem(event)),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildApprovalItem(EventModel event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: U.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: U.peach.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.outfit(color: U.peach, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'By ${event.conductedBy.isNotEmpty ? event.conductedBy : event.organizerName}',
            style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: U.dim),
              const SizedBox(width: 4),
              Text(_formatDate(event.date), style: GoogleFonts.outfit(fontSize: 12, color: U.dim)),
              const SizedBox(width: 12),
              Icon(Icons.category_rounded, size: 12, color: U.dim),
              const SizedBox(width: 4),
              Text(event.category, style: GoogleFonts.outfit(fontSize: 12, color: U.dim)),
            ],
          ),
          if (event.shortDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.shortDescription,
              style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectEvent(event),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: U.red,
                    side: BorderSide(color: U.red.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveEvent(event),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: U.primary,
                    foregroundColor: U.bg,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
