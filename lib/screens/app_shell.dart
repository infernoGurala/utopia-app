import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'attendance_screen.dart';
import 'university_screen.dart';
import 'home_screen.dart';
import 'iaa_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _tabAnimationController;

  final _screens = [
    const HomeScreen(),
    const AttendanceScreen(),
    const UniversityScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
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
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: U.bg,
          body: AnimatedBuilder(
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
                  child: IndexedStack(index: _index, children: _screens),
                ),
              );
            },
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: U.surface,
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.auto_stories_outlined,
                        selectedIcon: Icons.auto_stories,
                        label: 'Library',
                        selected: _index == 0,
                        onTap: () => _setIndex(0),
                      ),
                    ),
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.fact_check_outlined,
                        selectedIcon: Icons.fact_check,
                        label: 'Attendance',
                        selected: _index == 1,
                        onTap: () => _setIndex(1),
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      child: _FeaturedAIDestinationIcon(
                        active: true,
                        onTap: () =>
                            Navigator.of(context).push(IAAScreen.route()),
                      ),
                    ),
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.school_outlined,
                        selectedIcon: Icons.school,
                        label: 'University',
                        selected: _index == 2,
                        onTap: () => _setIndex(2),
                      ),
                    ),
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'Profile',
                        selected: _index == 3,
                        onTap: () => _setIndex(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeaturedAIDestinationIcon extends StatelessWidget {
  const _FeaturedAIDestinationIcon({this.active = false, this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glowColor = active ? U.primary : const Color(0xFF8F85E8);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFF201A35),
              glowColor.withValues(alpha: active ? 0.88 : 0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: glowColor.withValues(alpha: active ? 0.46 : 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: active ? 0.18 : 0.12),
              blurRadius: active ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          color: const Color(0xFFF7F0FF),
          size: 24,
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: 22,
      color: selected ? U.primary : U.dim,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: selected ? U.primary : U.sub,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
