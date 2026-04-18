import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'attendance_screen.dart';
import 'university_screen.dart';
import 'home_screen.dart';
import 'library_home_screen.dart';
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

  final List<Widget?> _screens = [
    const LibraryHomeScreen(),
    null,
    null,
    null,
  ];

  Widget _getScreen(int index) {
    if (_screens[index] == null) {
      switch (index) {
        case 1:
          _screens[index] = const AttendanceScreen();
          break;
        case 2:
          _screens[index] = const UniversityScreen();
          break;
        case 3:
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
                  child: IndexedStack(
                    index: _index,
                    children: [
                      _index == 0 ? _getScreen(0) : (_screens[0] ?? const SizedBox.shrink()),
                      _index == 1 ? _getScreen(1) : (_screens[1] ?? const SizedBox.shrink()),
                      _index == 2 ? _getScreen(2) : (_screens[2] ?? const SizedBox.shrink()),
                      _index == 3 ? _getScreen(3) : (_screens[3] ?? const SizedBox.shrink()),
                    ],
                  ),
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
                child: ValueListenableBuilder<bool>(
                  valueListenable: iaaEnabledNotifier,
                  builder: (context, iaaEnabled, _) {
                    return Row(
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
                        if (iaaEnabled)
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
                    );
                  },
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

class _BottomNavItem extends StatefulWidget {
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
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.65, end: 1.18).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    if (widget.selected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _BottomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                final scale = widget.selected ? _scaleAnimation.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.selected ? 18 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? U.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  widget.selected ? widget.selectedIcon : widget.icon,
                  size: 22,
                  color: widget.selected ? U.primary : U.dim,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.outfit(
                color: widget.selected ? U.primary : U.sub,
                fontSize: 11,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}
