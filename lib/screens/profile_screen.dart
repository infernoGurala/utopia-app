import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/cache_service.dart';
import '../services/platform_support.dart';
import '../widgets/game_champion_badge.dart';
import '../services/role_service.dart';
import '../services/game_champion_service.dart';
import 'about_utopia_screen.dart';
import 'developer_panel_screen.dart';
import 'university_selection_screen.dart';
import 'iaa_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSuperUser = false;
  bool _updatingName = false;
  bool _updatingTheme = false;

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
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  Future<void> _launchBugReport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'johnmosesg150@gmail.com',
      query: 'subject=UTOPIA Bug Report / Suggestion',
    );
    try {
      if (!await launchUrl(emailLaunchUri)) {
        throw Exception('Could not launch email');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: U.red,
            content: Text(
              'Could not open email app. Please email johnmosesg150@gmail.com directly.',
              style: GoogleFonts.outfit(color: U.bg, fontSize: 13),
            ),
          ),
        );
      }
    }
  }

  void _restartApp() async {
    try {
      const platform = MethodChannel('utopia_app/app_update');
      await platform.invokeMethod('restartApp');
    } catch (e) {
      SystemNavigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    RoleService().isSuperUser().then((v) {
      if (mounted) setState(() => _isSuperUser = v);
    });
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

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profile',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: U.text,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -1,
                              shadows: [
                                Shadow(
                                  color: U.text.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Manage your academic identity',
                      style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),
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
                                      isSuperUser: _isSuperUser,
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
                            ],
                          ),
                        );
                      },
                    );

                  },
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: U.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: U.border),
                  ),
                  child: Column(
                    children: [
                      if (_isSuperUser) ...[
                        _groupedTile(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Admin Control Panel',
                          sub: 'Manage announcements, notifications, and timetable',
                          color: U.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeveloperPanelScreen(),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: U.border.withValues(alpha: 0.5),
                        ),
                      ],
                      _groupedTile(
                        icon: Icons.info_outline_rounded,
                        label: 'About UTOPIA',
                        sub: 'Version 3.0.0 · Early Access Rollout',
                        color: U.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutUtopiaScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),
                      // Switch Theme
                      _groupedTile(
                        icon: Icons.palette_outlined,
                        label: 'Switch Theme',
                        sub: _updatingTheme ? 'Updating theme...' : '${U.themeForKey(U.currentThemeKey).label} theme',
                        color: U.primary,
                        onTap: _selectThemeStyle,
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),
                      // Change University
                      _groupedTile(
                        icon: Icons.school_outlined,
                        label: 'Change University',
                        sub: 'Switch to a different university',
                        color: U.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UniversitySelectionScreen(),
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),
                      // IAA Assistant
                      _groupedTile(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Intelligent Academic Assistant',
                        sub: 'Get AI-powered insights',
                        color: const Color(0xFF7F77DD),
                        onTap: () => Navigator.of(context).push(IAAScreen.route()),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),

                      // Report Bugs & Suggestions
                      _groupedTile(
                        icon: Icons.bug_report_outlined,
                        label: 'Report Bugs & Suggestions',
                        sub: 'Help us improve UTOPIA',
                        color: U.teal,
                        onTap: _launchBugReport,
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: U.red,
                    side: BorderSide(color: U.red.withValues(alpha: 0.3), width: 1),
                    backgroundColor: U.red.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_outlined, size: 20, color: U.red),
                      const SizedBox(width: 8),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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
      initialChildSize: 0.80,
      minChildSize: 0.48,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: U.border),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose your vibe',
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: appThemes.length,
                    itemBuilder: (context, index) {
                      final theme = appThemes[index];
                      final selected = theme.key == currentKey;
                      return _ThemePreviewCard(
                        theme: theme,
                        selected: selected,
                        onTap: () => Navigator.pop(context, theme.key),
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

/// A mini preview card that renders a realistic miniature of the theme.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? theme.primary : theme.border,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.primary.withValues(alpha: 0.30),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              // ── Mini UI mockup ──
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar (mock app bar)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.text.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 14,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.dim.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Mock card 1
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.border.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 5,
                            width: 50,
                            decoration: BoxDecoration(
                              color: theme.text.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 4,
                            width: 80,
                            decoration: BoxDecoration(
                              color: theme.sub.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Accent color dots row
                          Row(
                            children: [
                              _dot(theme.primary, 8),
                              const SizedBox(width: 4),
                              _dot(theme.teal, 8),
                              const SizedBox(width: 4),
                              _dot(theme.peach, 8),
                              const SizedBox(width: 4),
                              _dot(theme.blue, 8),
                              const SizedBox(width: 4),
                              _dot(theme.green, 8),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mock card 2 — mini list items
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.border.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _mockListItem(theme, theme.primary),
                          const SizedBox(height: 5),
                          _mockListItem(theme, theme.teal),
                          const SizedBox(height: 5),
                          _mockListItem(theme, theme.peach),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mock button
                    Container(
                      width: double.infinity,
                      height: 22,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Container(
                          height: 4,
                          width: 30,
                          decoration: BoxDecoration(
                            color: theme.bg.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // ── Theme name label at bottom ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.bg.withValues(alpha: 0.0),
                        theme.bg.withValues(alpha: 0.85),
                        theme.bg,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              theme.label,
                              style: GoogleFonts.outfit(
                                color: theme.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              theme.description,
                              style: GoogleFonts.outfit(
                                color: theme.sub,
                                fontSize: 9,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: theme.primary,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _mockListItem(AppTheme t, Color accent) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: t.text.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 8,
          height: 4,
          decoration: BoxDecoration(
            color: t.dim.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
