import 'dart:ui';
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
                          _index == 3 ? _getScreen(3) : (_screens[3] ?? const SizedBox.shrink()),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: iaaEnabledNotifier,
                          builder: (context, iaaEnabled, _) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _BottomNavItem(
                                    icon: Icons.auto_stories_outlined,
                                    selectedIcon: Icons.auto_stories_rounded,
                                    selected: _index == 0,
                                    onTap: () => _setIndex(0),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomNavItem(
                                    icon: Icons.fact_check_outlined,
                                    selectedIcon: Icons.fact_check_rounded,
                                    selected: _index == 1,
                                    onTap: () => _setIndex(1),
                                  ),
                                ),
                                if (iaaEnabled)
                                  SizedBox(
                                    width: 64,
                                    child: _FeaturedAIDestinationIcon(
                                      active: true,
                                      onTap: () =>
                                          Navigator.of(context).push(IAAScreen.route()),
                                    ),
                                  ),
                                Expanded(
                                  child: _BottomNavItem(
                                    icon: Icons.school_outlined,
                                    selectedIcon: Icons.school_rounded,
                                    selected: _index == 2,
                                    onTap: () => _setIndex(2),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomNavItem(
                                    icon: Icons.person_outline_rounded,
                                    selectedIcon: Icons.person_rounded,
                                    selected: _index == 3,
                                    onTap: () => _setIndex(3),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    }),
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

class _FeaturedAIDestinationIcon extends StatelessWidget {
  const _FeaturedAIDestinationIcon({this.active = false, this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glowColor = U.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark 
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          border: Border.all(
            color: glowColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          color: glowColor,
          size: 22,
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
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
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    if (widget.selected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _BottomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.forward(from: 0);
    } else if (!widget.selected && oldWidget.selected) {
      _controller.reverse();
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.selected ? _scaleAnimation.value : 1.0,
                child: child,
              );
            },
            child: Icon(
              widget.selected ? widget.selectedIcon : widget.icon,
              size: 24,
              color: widget.selected ? U.primary : U.dim,
            ),
          ),
          const SizedBox(height: 4),
          // Dot indicator
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.selected ? 1.0 : 0.0,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: U.primary,
                boxShadow: [
                  BoxShadow(
                    color: U.primary.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
