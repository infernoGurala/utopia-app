import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import 'university_screen.dart';
import 'library_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _tabAnimationController;

  final List<Widget?> _screens = [
    const LibraryHomeScreen(),
    null,
    null,
  ];

  Widget _getScreen(int index) {
    if (_screens[index] == null) {
      switch (index) {
        case 1:
          _screens[index] = const UniversityScreen();
          break;
        case 2:
          _screens[index] = const ProfileScreen();
          break;
      }
    }
    return _screens[index]!;
  }

  @override
  void initState() {
    super.initState();
    _tabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPopupEvent();
    });
  }

  Future<void> _checkPopupEvent() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
      final prefs = await SharedPreferences.getInstance();

      final eventId = doc.data()?['popup_event_id'] as String?;
      if (eventId != null && eventId.isNotEmpty) {
        final lastSeen = prefs.getString('last_seen_popup_event_id');
        if (lastSeen != eventId) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: U.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: U.primary.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: U.primary.withValues(alpha: 0.2),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: U.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome, color: U.primary, size: 36),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Share UTOPIA',
                        style: GoogleFonts.playfairDisplay(
                          color: U.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Love using UTOPIA? Help your friends elevate their university experience by inviting them to the app!',
                        style: GoogleFonts.outfit(color: U.sub, fontSize: 15, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: U.text,
                                side: BorderSide(color: U.border),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text('Later', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: U.primary,
                                foregroundColor: U.bg,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Share.share('Join me on UTOPIA! 🚀 The best app for our university.\n\nhttps://inferalis.space/download-utopia');
                                Navigator.pop(context);
                              },
                              child: Text('Share App', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            await prefs.setString('last_seen_popup_event_id', eventId);
          }
        }
      }

      final webEventId = doc.data()?['web_popup_event_id'] as String?;
      if (webEventId != null && webEventId.isNotEmpty) {
        final lastSeenWeb = prefs.getString('last_seen_web_popup_event_id');
        if (lastSeenWeb != webEventId) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: U.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: U.primary.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: U.primary.withValues(alpha: 0.2),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: U.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.language_rounded, color: U.primary, size: 36),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'UTOPIA Web',
                        style: GoogleFonts.playfairDisplay(
                          color: U.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Did you know UTOPIA is available on the web? Access your timetable, chat, and notes from any browser!',
                        style: GoogleFonts.outfit(color: U.sub, fontSize: 15, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: U.text,
                                side: BorderSide(color: U.border),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text('Later', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: U.primary,
                                foregroundColor: U.bg,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                launchUrl(Uri.parse('https://utopia.inferalis.space'), mode: LaunchMode.externalApplication);
                                Navigator.pop(context);
                              },
                              child: Text('Open Web', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            await prefs.setString('last_seen_web_popup_event_id', webEventId);
          }
        }
      }
    } catch (e) {
      // Ignore errors silently
    }
  }

  @override
  void dispose() {
    _tabAnimationController.dispose();
    super.dispose();
  }

  void _setIndex(int nextIndex) {
    if (nextIndex == _index) {
      return;
    }
    _tabAnimationController.forward(from: 0);
    setState(() => _index = nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: U.bg,
          extendBody: true,
          body: Stack(
            children: [
              AnimatedBuilder(
                animation: _tabAnimationController,
                builder: (context, child) {
                  final opacity = Tween<double>(begin: 0.92, end: 1).evaluate(
                    CurvedAnimation(
                      parent: _tabAnimationController,
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  final scale = Tween<double>(begin: 0.985, end: 1).evaluate(
                    CurvedAnimation(
                      parent: _tabAnimationController,
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: IndexedStack(
                        index: _index,
                        children: [
                          _index == 0 ? _getScreen(0) : (_screens[0] ?? const SizedBox.shrink()),
                          _index == 1 ? _getScreen(1) : (_screens[1] ?? const SizedBox.shrink()),
                          _index == 2 ? _getScreen(2) : (_screens[2] ?? const SizedBox.shrink()),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Floating glassmorphic nav bar
              Positioned(
                left: 60,
                right: 60,
                bottom: MediaQuery.paddingOf(context).bottom + 24,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  offset: isKeyboardOpen ? const Offset(0, 1.5) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isKeyboardOpen ? 0.0 : 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Builder(builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final accent = U.primary;
                          return Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _NavItem(
                                  icon: Icons.auto_stories_outlined,
                                  activeIcon: Icons.auto_stories_rounded,
                                  isActive: _index == 0,
                                  accent: accent,
                                  isDark: isDark,
                                  onTap: () => _setIndex(0),
                                ),
                                _NavItem(
                                  icon: Icons.school_outlined,
                                  activeIcon: Icons.school_rounded,
                                  isActive: _index == 1,
                                  accent: accent,
                                  isDark: isDark,
                                  onTap: () => _setIndex(1),
                                ),
                                _NavItem(
                                  icon: Icons.person_outline_rounded,
                                  activeIcon: Icons.person_rounded,
                                  isActive: _index == 2,
                                  accent: accent,
                                  isDark: isDark,
                                  onTap: () => _setIndex(2),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive
                    ? accent
                    : isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.35),
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            // Active indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isActive ? 4 : 0,
              height: isActive ? 4 : 0,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
