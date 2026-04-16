import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import '../services/cache_service.dart';
import '../services/platform_support.dart';
import '../widgets/game_champion_badge.dart';
import '../services/role_service.dart';
import '../services/game_champion_service.dart';
import 'developer_panel_screen.dart';
import 'sciwordle_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isWriter = false;
  bool _updatingName = false;
  bool _updatingTheme = false;

  @override
  void initState() {
    super.initState();
    RoleService().isWriter().then((v) {
      if (mounted) setState(() => _isWriter = v);
    });
  }

  Future<void> _signOut() async {
    RoleService().clearCache();
    if (PlatformSupport.supportsGoogleSignIn) {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '402670858978-94eqn0qvvrtv59ijne3hn1g5flr4ahve.apps.googleusercontent.com',
      );
      await GoogleSignIn.instance.signOut();
    }
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _editDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _updatingName) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _EditDisplayNameDialog(initialValue: user.displayName ?? ''),
    );

    if (nextName == null || nextName.isEmpty || nextName == user.displayName) {
      return;
    }

    setState(() => _updatingName = true);
    try {
      await user.updateDisplayName(nextName);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': nextName,
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.reload();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: U.red,
            content: Text(
              'Could not update display name',
              style: GoogleFonts.outfit(color: U.bg),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingName = false);
      }
    }
  }

  Future<void> _selectThemeStyle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _updatingTheme) {
      return;
    }

    final selectedKey = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThemeStyleSheet(currentKey: U.currentThemeKey),
    );

    if (selectedKey == null || selectedKey == U.currentThemeKey) {
      return;
    }

    setState(() => _updatingTheme = true);
    final previousKey = U.currentThemeKey;
    U.applyTheme(selectedKey);
    unawaited(CacheService().saveAppSetting('theme_accent', selectedKey));
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'themeAccent': selectedKey,
      }, SetOptions(merge: true));
      _restartApp();
    } catch (e) {
      U.applyTheme(previousKey);
      unawaited(CacheService().saveAppSetting('theme_accent', previousKey));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: U.red,
            content: Text(
              'Could not update theme style',
              style: GoogleFonts.outfit(color: U.bg),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingTheme = false);
      }
    }
  }

  void _restartApp() async {
    // Use platform channel to restart app on Android
    try {
      const platform = MethodChannel('utopia_app/app_update');
      await platform.invokeMethod('restartApp');
    } catch (e) {
      // Fallback to system navigator
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final styleLabel = U.themeForKey(U.currentThemeKey).label;
    final user = FirebaseAuth.instance.currentUser;
    final userDocStream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: U.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                StreamBuilder<Map<String, int>>(
                  stream: GameChampionService.topScoreRanksStream(),
                  builder: (context, scoreRanksSnapshot) {
                    return StreamBuilder<Map<String, int>>(
                      stream: GameChampionService.topStreakRanksStream(),
                      builder: (context, streakRanksSnapshot) {
                        final uid = user?.uid;
                        final scoreRank = uid != null
                            ? (scoreRanksSnapshot.data?[uid])
                            : null;
                        final streakRank = uid != null
                            ? (streakRanksSnapshot.data?[uid])
                            : null;
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: U.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: U.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ChampionAvatarBadge(
                                scoreRank: scoreRank,
                                streakRank: streakRank,
                                email: user?.email,
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: U.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  backgroundImage: user?.photoURL != null
                                      ? NetworkImage(user!.photoURL!)
                                      : null,
                                  child: user?.photoURL == null
                                      ? Text(
                                          (user?.displayName ?? 'U')[0]
                                              .toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            color: U.primary,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ChampionNameText(
                                      name: user?.displayName ?? 'Student',
                                      scoreRank: scoreRank,
                                      streakRank: streakRank,
                                      email: user?.email,
                                      style: GoogleFonts.outfit(
                                        color: U.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.email ?? '',
                                      style: GoogleFonts.outfit(
                                        color: U.sub,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _editDisplayName,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            color: _updatingName
                                                ? U.dim
                                                : U.primary,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _updatingName
                                                ? 'Updating...'
                                                : 'Edit display name',
                                            style: GoogleFonts.outfit(
                                              color: _updatingName
                                                  ? U.dim
                                                  : U.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _isWriter
                                      ? U.primary.withValues(alpha: 0.15)
                                      : U.border,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _isWriter ? 'Writer' : 'Reader',
                                  style: GoogleFonts.outfit(
                                    color: _isWriter ? U.primary : U.sub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (_isWriter) ...[
                  _tile(
                    icon: Icons.developer_mode_outlined,
                    label: 'Developer Panel',
                    sub: 'Manage notifications and timetable',
                    color: U.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeveloperPanelScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _tile(
                  icon: Icons.science_outlined,
                  label: 'SciWordle',
                  sub: 'Daily science word game',
                  color: U.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SciwordleScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Settings Section ──
                Text(
                  'Settings',
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: U.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: U.border),
                  ),
                  child: Column(
                    children: [
                      // Color Style
                      _groupedTile(
                        icon: Icons.palette_outlined,
                        label: 'Color Style',
                        sub: _updatingTheme
                            ? 'Updating theme...'
                            : '$styleLabel theme',
                        color: U.primary,
                        onTap: _selectThemeStyle,
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),
                      // IAA Assistant Toggle
                      ValueListenableBuilder<bool>(
                        valueListenable: iaaEnabledNotifier,
                        builder: (context, iaaEnabled, _) {
                          return _groupedToggleTile(
                            icon: Icons.auto_awesome_rounded,
                            label: 'IAA Assistant',
                            sub: iaaEnabled
                                ? 'Enabled · Shows in bottom navigation'
                                : 'Disabled · Hidden from bottom navigation',
                            color: iaaEnabled ? U.primary : U.dim,
                            value: iaaEnabled,
                            onChanged: (v) async {
                              iaaEnabledNotifier.value = v;
                              unawaited(
                                CacheService().saveAppSetting(
                                  'iaa_enabled',
                                  v.toString(),
                                ),
                              );
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid != null) {
                                unawaited(
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .set({
                                        'iaaEnabled': v,
                                      }, SetOptions(merge: true)),
                                );
                              }
                            },
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),
                      // Sign out
                      _groupedTile(
                        icon: Icons.logout_outlined,
                        label: 'Sign out',
                        sub: 'Sign out of your account',
                        color: U.red,
                        onTap: _signOut,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'UTOPIA · designed by Inferno',
                    style: GoogleFonts.outfit(color: U.dim, fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: U.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: U.dim, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _groupedTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: U.dim, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _groupedToggleTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: U.primary,
            activeTrackColor: U.primary.withValues(alpha: 0.35),
            inactiveThumbColor: U.dim,
            inactiveTrackColor: U.border,
          ),
        ],
      ),
    );
  }
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: U.card,
      title: Text(
        'Edit name',
        style: GoogleFonts.outfit(
          color: U.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: GoogleFonts.outfit(color: U.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Display name',
          hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: U.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: U.primary),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: U.primary,
            foregroundColor: U.bg,
          ),
          child: Text(
            'Save',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ThemeStyleSheet extends StatelessWidget {
  const _ThemeStyleSheet({required this.currentKey});

  final String currentKey;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: U.border),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: U.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Theme',
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose your preferred theme',
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: appThemes.length,
                    itemBuilder: (context, index) {
                      final theme = appThemes[index];
                      final selected = theme.key == currentKey;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, theme.key),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: U.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected ? theme.primary : U.border,
                                width: selected ? 1.2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: theme.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.primary.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    selected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.dark_mode_rounded,
                                    color: theme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        theme.label,
                                        style: GoogleFonts.outfit(
                                          color: U.text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        theme.description,
                                        style: GoogleFonts.outfit(
                                          color: U.sub,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: theme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
