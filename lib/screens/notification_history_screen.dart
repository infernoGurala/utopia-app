import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/notification_dialog.dart';
import '../widgets/utopia_snackbar.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  Future<void> _deleteNotification(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .delete();
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Notification deleted',
          tone: UtopiaSnackBarTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Could not delete notification',
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF313244),
        title: const Text(
          'Clear all notifications?',
          style: TextStyle(color: Color(0xFFCDD6F4)),
        ),
        content: const Text(
          'This will permanently remove every notification from your history.',
          style: TextStyle(color: Color(0xFFA6ADC8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFA6ADC8)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF38BA8),
              foregroundColor: const Color(0xFF11111B),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: user.uid)
          .get();

      var batch = FirebaseFirestore.instance.batch();
      var operationCount = 0;
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        operationCount++;
        if (operationCount == 400) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }
      if (operationCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Notification history cleared',
          tone: UtopiaSnackBarTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Could not clear notifications',
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'All notifications marked as read',
          tone: UtopiaSnackBarTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Could not mark notifications as read',
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _openNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(doc.id)
          .update({'read': true});
      final data = doc.data();
      showNotificationDialog(
        title: data['title'] ?? '',
        body: data['body'] ?? '',
      );
    } catch (e) {
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Could not open notification',
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return '';
    }
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final meridiem = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $meridiem';
    }
    if (difference == 1) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  String _sectionLabel(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Earlier';
    }
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Icon _notificationIcon(String type) {
    switch (type) {
      case 'morning_notification':
        return const Icon(Icons.wb_sunny, color: Color(0xFFF9E2AF));
      case 'broadcast':
        return const Icon(Icons.campaign, color: Color(0xFFCBA6F7));
      default:
        return const Icon(Icons.notifications, color: Color(0xFF89B4FA));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final query = FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: currentUserUid)
        .limit(50);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        foregroundColor: const Color(0xFFCDD6F4),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _clearAll,
            tooltip: 'Clear all',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFF38BA8),
            ),
          ),
          TextButton(
            onPressed: _markAllRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Color(0xFFCBA6F7)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is FirebaseException &&
                error.code == 'failed-precondition') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                showUtopiaSnackBar(
                  context,
                  message: 'Please wait, setting up notifications index...',
                  tone: UtopiaSnackBarTone.info,
                );
              });
            }
            return const Center(
              child: Text(
                'Notifications are not ready yet.',
                style: TextStyle(color: Color(0xFFA6ADC8)),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFCBA6F7)),
            );
          }

          final docs = [...(snapshot.data?.docs ?? [])]..sort((a, b) {
            final aTimestamp = a.data()['receivedAt'] as Timestamp?;
            final bTimestamp = b.data()['receivedAt'] as Timestamp?;
            final aMicros =
                aTimestamp?.microsecondsSinceEpoch ?? DateTime(1970).microsecondsSinceEpoch;
            final bMicros =
                bTimestamp?.microsecondsSinceEpoch ?? DateTime(1970).microsecondsSinceEpoch;
            return bMicros.compareTo(aMicros);
          });
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: Color(0xFF6C7086),
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Color(0xFFA6ADC8)),
                  ),
                ],
              ),
            );
          }

          String? lastSection;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final bool isUnread = !(data['read'] as bool? ?? false);
              final title = (data['title'] ?? '').toString();
              final body = (data['body'] ?? '').toString();
              final type = (data['type'] ?? 'general').toString();
              final receivedAt = data['receivedAt'] as Timestamp?;
              final section = _sectionLabel(receivedAt);
              final showSection = section != lastSection;
              lastSection = section;

              return Padding(
                padding: EdgeInsets.only(top: showSection ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSection) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 4),
                        child: Text(
                          section,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFFCBA6F7),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                    Dismissible(
                      key: ValueKey(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF312127),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF38BA8)),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFF5B0C3),
                        ),
                      ),
                      onDismissed: (_) => _deleteNotification(doc.id),
                      child: _NotificationCard(
                        title: title,
                        body: body,
                        type: type,
                        isUnread: isUnread,
                        timeLabel: _formatTime(receivedAt),
                        icon: _notificationIcon(type),
                        onTap: () => _openNotification(doc),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.body,
    required this.type,
    required this.isUnread,
    required this.timeLabel,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String body;
  final String type;
  final bool isUnread;
  final String timeLabel;
  final Icon icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF313244),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread
                  ? const Color(0xFF4D4567)
                  : const Color(0xFF3C3E52),
            ),
            gradient: LinearGradient(
              colors: isUnread
                  ? const [Color(0xFF34364A), Color(0xFF2D3043)]
                  : const [Color(0xFF313244), Color(0xFF2A2C3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF252738),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5, right: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFCBA6F7),
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(0xFFEEF0FA),
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF9EA3BE),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFAEB3CD),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25263A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            switch (type) {
                              'morning_notification' => 'Morning',
                              'broadcast' => 'Broadcast',
                              _ => 'General',
                            },
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFCBA6F7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.swipe_left_rounded,
                          color: Color(0xFF6C7086),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
