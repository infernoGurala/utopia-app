import 'package:flutter/material.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/services/notification_service.dart';

class _PendingNotificationDialog {
  const _PendingNotificationDialog({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

_PendingNotificationDialog? _pendingNotificationDialog;
bool _notificationDialogDrainScheduled = false;

void _schedulePendingNotificationDrain() {
  if (_notificationDialogDrainScheduled) {
    return;
  }
  _notificationDialogDrainScheduled = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _notificationDialogDrainScheduled = false;
    final pending = _pendingNotificationDialog;
    if (pending == null) {
      return;
    }

    final context = navigatorKey.currentContext ?? navigatorKey.currentState?.overlay?.context;
    if (context == null) {
      _schedulePendingNotificationDrain();
      return;
    }

    _pendingNotificationDialog = null;
    showNotificationDialog(title: pending.title, body: pending.body);
  });
}

void showNotificationDialog({
  required String title,
  required String body,
}) {
  if (NotificationService.isDialogShowing) return;
  final context = navigatorKey.currentContext ?? navigatorKey.currentState?.overlay?.context;
  if (context == null) {
    _pendingNotificationDialog = _PendingNotificationDialog(
      title: title,
      body: body,
    );
    _schedulePendingNotificationDrain();
    return;
  }
  NotificationService.isDialogShowing = true;
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Notification',
    barrierColor: const Color(0xAA0F0F17),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, animation, secondaryAnimation) => AlertDialog(
      backgroundColor: const Color(0xFF313244),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.notifications, color: Color(0xFFCBA6F7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        body,
        style: const TextStyle(color: Color(0xFFCDD6F4)),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            NotificationService.isDialogShowing = false;
            Navigator.of(ctx).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFCBA6F7),
          ),
          child: const Text(
            'Dismiss',
            style: TextStyle(color: Color(0xFF1E1E2E)),
          ),
        ),
      ],
    ),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  ).then((_) {
    NotificationService.isDialogShowing = false;
  });
}
