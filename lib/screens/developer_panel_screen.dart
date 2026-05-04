import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/notification_service.dart';
import '../services/writer_firestore_service.dart';
import '../widgets/utopia_snackbar.dart';
import 'broadcast_screen.dart';
import 'quotes_editor_screen.dart';
import 'timetable_editor_screen.dart';

class DeveloperPanelScreen extends StatefulWidget {
  const DeveloperPanelScreen({super.key});

  @override
  State<DeveloperPanelScreen> createState() => _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends State<DeveloperPanelScreen> {
  bool _holidayLoading = true;
  bool _holidayTomorrow = false;
  bool _savingHoliday = false;
  bool _sendingMorningNotification = false;
  bool _sendingPersonalMorningNotification = false;
  bool _sendingPersonalNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHolidayState();
    });
  }

  Future<void> _loadHolidayState() async {
    try {
      final data = await WriterFirestoreService.fetchConfig('morning_notif');
      final notif = data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (!mounted) {
        return;
      }
      setState(() {
        _holidayTomorrow = notif['holiday'] == true;
        _holidayLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _holidayLoading = false;
      });
      showUtopiaSnackBar(
        context,
        message: 'Could not load holiday settings',
        tone: UtopiaSnackBarTone.error,
      );
    }
  }

  Future<void> _triggerPopupEvent() async {
    try {
      final newEventId = DateTime.now().millisecondsSinceEpoch.toString();
      final data = await WriterFirestoreService.fetchConfig('app_config');
      final currentData = data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      currentData['popup_event_id'] = newEventId;
      await WriterFirestoreService.updateConfig('app_config', currentData);
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Pop-up event triggered',
          tone: UtopiaSnackBarTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Could not trigger pop-up event',
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _triggerWebPopupEvent() async {
    try {
      final newEventId = DateTime.now().millisecondsSinceEpoch.toString();
      final data = await WriterFirestoreService.fetchConfig('app_config');
      final currentData = data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      currentData['web_popup_event_id'] = newEventId;
      await WriterFirestoreService.updateConfig('app_config', currentData);
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Web Pop-up event triggered',
          tone: UtopiaSnackBarTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Could not trigger web pop-up event',
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _toggleHoliday(bool value) async {
    if (_savingHoliday) {
      return;
    }
    setState(() {
      _savingHoliday = true;
    });

    try {
      final data = await WriterFirestoreService.fetchConfig('morning_notif');
      final currentData = data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final nextData = Map<String, dynamic>.from(currentData);
      nextData['holiday'] = value;
      await WriterFirestoreService.updateConfig('morning_notif', nextData);

      if (!mounted) {
        return;
      }

      setState(() {
        _holidayTomorrow = value;
      });

      showUtopiaSnackBar(
        context,
        message: value ? 'Holiday set for tomorrow' : 'Holiday removed',
        tone: UtopiaSnackBarTone.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not update holiday',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingHoliday = false;
        });
      }
    }
  }

  Future<void> _confirmAndSendMorningNotification() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: U.surface,
            title: Text(
              'Send now?',
              style: GoogleFonts.outfit(color: U.text),
            ),
            content: Text(
              'This will send today\'s morning notification to all students immediately.',
              style: GoogleFonts.outfit(color: U.sub),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(color: U.sub),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: U.primary,
                  foregroundColor: U.bg,
                ),
                child: const Text('Send'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      setState(() {
        _sendingMorningNotification = true;
      });

      final patDoc = await WriterFirestoreService.fetchConfig('github');
      final pat = patDoc?['pat'] as String? ?? '';
      const owner = 'infernoGurala';
      const repo = 'utopia-content';
      final url =
          'https://api.github.com/repos/$owner/$repo/actions/workflows/morning_notification.yml/dispatches';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $pat',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ref': 'main'}),
      );
      if (!mounted) {
        return;
      }

      if (response.statusCode == 204) {
        showUtopiaSnackBar(
          context,
          message:
              'Morning notification triggered. Arrives in about 30 seconds',
          tone: UtopiaSnackBarTone.success,
        );
      } else {
        throw Exception(
          'GitHub workflow dispatch failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not trigger morning notification',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingMorningNotification = false;
        });
      }
    }
  }

  Future<void> _sendPersonalNotification() async {
    if (_sendingPersonalNotification) {
      return;
    }

    final controller = TextEditingController();
    try {
      final message = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: U.surface,
            title: Text(
              'Send Personal Test',
              style: GoogleFonts.outfit(color: U.text),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 200,
              maxLines: 4,
              minLines: 3,
              style: GoogleFonts.outfit(color: U.text),
              decoration: InputDecoration(
                hintText: 'Message to send only to your device',
                hintStyle: GoogleFonts.outfit(color: U.dim),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(color: U.sub),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: U.primary,
                  foregroundColor: U.bg,
                ),
                child: const Text('Send'),
              ),
            ],
          );
        },
      );

      if (!mounted || message == null || message.isEmpty) {
        return;
      }

      setState(() {
        _sendingPersonalNotification = true;
      });

      await NotificationService.sendPersonalTestNotification(message: message);

      if (!mounted) {
        return;
      }

      showUtopiaSnackBar(
        context,
        message: 'Personal test notification sent to your device',
        tone: UtopiaSnackBarTone.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not send personal notification',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() {
          _sendingPersonalNotification = false;
        });
      }
    }
  }

  Future<void> _sendPersonalMorningNotification() async {
    if (_sendingPersonalMorningNotification) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No signed-in user');
      }

      setState(() {
        _sendingPersonalMorningNotification = true;
      });

      final patDoc = await WriterFirestoreService.fetchConfig('github');
      final pat = patDoc?['pat'] as String? ?? '';
      const owner = 'infernoGurala';
      const repo = 'utopia-content';
      const workflowFile = 'personal_morning_notification.yml';
      const ref = 'main';

      final response = await http.post(
        Uri.parse(
          'https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowFile/dispatches',
        ),
        headers: {
          'Authorization': 'Bearer $pat',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ref': ref,
          'inputs': {'uid': user.uid},
        }),
      );
      if (response.statusCode != 204) {
        throw Exception(
          'GitHub workflow dispatch failed: ${response.statusCode}',
        );
      }

      if (!mounted) {
        return;
      }

      showUtopiaSnackBar(
        context,
        message: 'Personal morning notification sent to your device',
        tone: UtopiaSnackBarTone.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not send personal morning notification',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingPersonalMorningNotification = false;
        });
      }
    }
  }

  Widget _sectionHeader(String text, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 16, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: U.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      color: U.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: U.primary),
        title: Text(
          title,
          style: TextStyle(
            color: U.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: U.sub),
        ),
        trailing:
            trailing ??
            Icon(Icons.chevron_right, color: U.dim),
        onTap: onTap,
      ),
    );
  }

  Widget _holidayCard() {
    return _toolCard(
      icon: Icons.beach_access,
      title: 'Tomorrow is a Holiday',
      subtitle: 'Toggle to send holiday notification tomorrow',
      trailing: _savingHoliday
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: U.primary,
              ),
            )
          : _holidayLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: U.dim,
              ),
            )
          : Switch(
              value: _holidayTomorrow,
              activeThumbColor: U.primary,
              onChanged: _toggleHoliday,
            ),
      onTap: (_savingHoliday || _holidayLoading)
          ? null
          : () => _toggleHoliday(!_holidayTomorrow),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: U.bg,
          appBar: AppBar(
            backgroundColor: U.bg,
            foregroundColor: U.text,
            title: Row(
              children: [
                Icon(Icons.edit, size: 18, color: U.primary),
                const SizedBox(width: 8),
                const Text('Developer Mode'),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader('🚀 Quick Actions', isFirst: true),
              _toolCard(
                icon: Icons.send,
                title: 'Send Morning Notification Now',
                subtitle: 'Manually trigger today\'s schedule to all students',
                trailing: _sendingMorningNotification
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: U.primary,
                        ),
                      )
                    : Icon(Icons.chevron_right, color: U.dim),
                onTap: _sendingMorningNotification
                    ? null
                    : _confirmAndSendMorningNotification,
              ),
              const SizedBox(height: 12),
              _toolCard(
                icon: Icons.wb_twilight_outlined,
                title: 'Send Personal Morning Notification',
                subtitle: 'Trigger today\'s morning notification only for you',
                trailing: _sendingPersonalMorningNotification
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: U.primary,
                        ),
                      )
                    : Icon(Icons.chevron_right, color: U.dim),
                onTap: _sendingPersonalMorningNotification
                    ? null
                    : _sendPersonalMorningNotification,
              ),
              const SizedBox(height: 12),
              _toolCard(
                icon: Icons.notifications_active_outlined,
                title: 'Send Personal Test Notification',
                subtitle: 'Send a custom push notification only to your account',
                trailing: _sendingPersonalNotification
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: U.primary,
                        ),
                      )
                    : Icon(Icons.chevron_right, color: U.dim),
                onTap: _sendingPersonalNotification
                    ? null
                    : _sendPersonalNotification,
              ),
              const SizedBox(height: 12),
              _sectionHeader('📢 Announcements'),
              _toolCard(
                icon: Icons.campaign,
                title: 'Broadcast Message',
                subtitle: 'Send urgent notification to all students',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BroadcastScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _toolCard(
                icon: Icons.celebration,
                title: 'Trigger Share Pop-up',
                subtitle: 'Show share pop-up to all users on next launch',
                onTap: _triggerPopupEvent,
              ),
              const SizedBox(height: 12),
              _toolCard(
                icon: Icons.web_rounded,
                title: 'Trigger Web Pop-up',
                subtitle: 'Show web version pop-up to all users',
                onTap: _triggerWebPopupEvent,
              ),
              const SizedBox(height: 12),
              _sectionHeader('📅 Timetable'),
              _toolCard(
                icon: Icons.edit_calendar,
                title: 'Edit Timetable',
                subtitle: 'Update subjects and times for each day',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TimetableEditorScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _sectionHeader('💬 Quotes'),
              _toolCard(
                icon: Icons.format_quote,
                title: 'Quotes Pool',
                subtitle: 'Add or remove daily motivational quotes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuotesEditorScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _sectionHeader('🏖️ Holiday'),
              _holidayCard(),
            ],
          ),
        );
      },
    );
  }
}

