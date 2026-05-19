import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../services/cache_service.dart';
import '../services/platform_support.dart';
import '../services/role_service.dart';
import 'university_selection_screen.dart';
import 'user_profile_screen.dart';
import 'utopia_section_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSuperUser = false;
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

  void _showChangePhotoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: U.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Change Profile Photo',
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Your profile photo is linked to your Google account.\n\nTo change it:\n1. Open your Google Account settings\n2. Update your profile picture there\n3. Sign out and sign back in to UTOPIA\n\nThe new photo will appear automatically after re-login.',
          style: GoogleFonts.outfit(color: U.sub, fontSize: 14, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: U.primary,
              foregroundColor: U.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Got it', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
    final isDark = appThemeNotifier.value.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
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
                        if (Navigator.canPop(context)) ...[
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: U.card,
                                shape: BoxShape.circle,
                                border: Border.all(color: U.border),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: U.text,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            'Profile',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: U.text,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage your academic identity',
                      style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),
                const SizedBox(height: 32),

                // Clean Minimal Profile Header
                Builder(
                  builder: (context) {
                    final bio = (snapshot.data?.data()?['bio'] ?? '').toString().trim();
                    return Column(
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureDetector(
                                onTap: () => _showChangePhotoDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: U.primary.withValues(alpha: 0.2), width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 44,
                                    backgroundColor: U.primary.withValues(alpha: 0.1),
                                    backgroundImage: user?.photoURL != null
                                        ? CachedNetworkImageProvider(user!.photoURL!)
                                        : null,
                                    child: user?.photoURL == null
                                        ? Text(
                                            (user?.displayName ?? 'U')[0].toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              color: U.primary,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showChangePhotoDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: U.card,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: U.border),
                                  ),
                                  child: Icon(Icons.camera_alt_outlined, size: 14, color: U.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                user?.displayName ?? 'Student',
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isSuperUser) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, color: Color(0xFF1D9BF0), size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: GoogleFonts.outfit(
                            color: U.sub,
                            fontSize: 13,
                          ),
                        ),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: U.text.withValues(alpha: 0.8),
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final updated = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _EditProfileSheet(
                                initialName: user?.displayName ?? 'Student',
                                initialBio: bio,
                              ),
                            );
                            if (updated == true && mounted) {
                              setState(() {});
                            }
                          },
                          icon: Icon(Icons.edit_outlined, size: 14, color: U.sub),
                          label: Text(
                            'Edit Profile',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: U.sub,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: U.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            backgroundColor: U.card.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Settings & Info List
                Container(
                  decoration: BoxDecoration(
                    color: U.card.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: U.border.withValues(alpha: 0.8)),
                  ),
                  child: Column(
                    children: [
                      // Public Profile
                      _groupedTile(
                        icon: Icons.public_outlined,
                        label: 'Public Profile',
                        sub: 'See how others view your profile',
                        color: U.primary,
                        onTap: () {
                          if (user == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                uid: user.uid,
                                displayName: user.displayName ?? 'Student',
                                email: user.email ?? '',
                                photoUrl: user.photoURL,
                              ),
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
                      // Share This App
                      _groupedTile(
                        icon: Icons.share_outlined,
                        label: 'Share This App',
                        sub: 'Invite friends to join UTOPIA',
                        color: U.primary,
                        onTap: () {
                          Share.share('Join me on UTOPIA! 🚀 The productivity platform.\n\nhttps://inferalis.space/download-utopia');
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: U.border.withValues(alpha: 0.5),
                      ),
                      // UTOPIA Section
                      _groupedTile(
                        icon: Icons.rocket_launch_outlined,
                        label: 'UTOPIA',
                        sub: 'About and development',
                        color: U.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UtopiaSectionScreen(
                              initialIsSuperUser: _isSuperUser,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Minimal Logout Button
                Center(
                  child: TextButton.icon(
                    onPressed: _signOut,
                    icon: Icon(Icons.logout_rounded, size: 16, color: U.red.withValues(alpha: 0.7)),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.outfit(
                        color: U.red.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'UTOPIA · Designed by Humans • Powered by AI',
                    style: GoogleFonts.outfit(color: U.dim, fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: U.dim, size: 16),
          ],
        ),
      ),
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

class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialBio;

  const _EditProfileSheet({
    required this.initialName,
    required this.initialBio,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _bioController = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nextName = _nameController.text.trim();
    final nextBio = _bioController.text.trim();

    if (nextName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: U.red,
          content: Text('Name cannot be empty', style: GoogleFonts.outfit(color: U.bg)),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update Auth
        await user.updateDisplayName(nextName);
        
        // Update Firestore users collection
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': nextName,
          'bio': nextBio,
          'email': user.email ?? '',
          'photoUrl': user.photoURL,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await user.reload();
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: U.red,
            content: Text('Could not update profile', style: GoogleFonts.outfit(color: U.bg)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: U.border.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'Edit Profile',
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(U.primary),
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(
                            color: U.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Name Field
            Text(
              'NAME',
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 40,
              style: GoogleFonts.outfit(color: U.text, fontSize: 15),
              cursorColor: U.primary,
              decoration: InputDecoration(
                hintText: 'Enter your name...',
                hintStyle: GoogleFonts.outfit(color: U.dim),
                counterText: '',
                filled: true,
                fillColor: U.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Bio Field
            Text(
              'BIO',
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 150,
              style: GoogleFonts.outfit(color: U.text, fontSize: 15),
              cursorColor: U.primary,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself...',
                hintStyle: GoogleFonts.outfit(color: U.dim),
                filled: true,
                fillColor: U.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

