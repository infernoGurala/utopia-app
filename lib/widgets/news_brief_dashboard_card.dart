import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../models/news_brief.dart';
import '../services/news_brief_repository.dart';
import '../screens/news_brief_screen.dart';

class NewsBriefDashboardCard extends StatefulWidget {
  const NewsBriefDashboardCard({super.key});

  @override
  State<NewsBriefDashboardCard> createState() => _NewsBriefDashboardCardState();
}

class _NewsBriefDashboardCardState extends State<NewsBriefDashboardCard> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPressed = false;
  List<NewsBrief> _allBriefs = [];
  int _activeBriefIndex = 0;
  int _categoryCount = 0;
  String _lastUpdatedStr = 'Updated just now';
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreviewData() async {
    if (!mounted) return;
    _rotationTimer?.cancel();
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final repo = NewsBriefRepository();

      // 1. Load cached briefs first for fast display
      var briefs = await repo.getTodaysBriefs();

      // 2. Query the actual last edge function run time from the server
      final serverFetchedAt = await repo.getLastFetchedAt();

      // 3. If the server has newer data than what we have cached, force refresh
      if (serverFetchedAt != null && briefs.isNotEmpty) {
        DateTime? cachedFetchedAt;
        for (final list in briefs.values) {
          for (final b in list) {
            if (b.fetchedAt != null) {
              if (cachedFetchedAt == null || b.fetchedAt!.isAfter(cachedFetchedAt)) {
                cachedFetchedAt = b.fetchedAt;
              }
            }
          }
        }

        // Server has newer data — auto-refresh
        if (cachedFetchedAt == null || serverFetchedAt.isAfter(cachedFetchedAt)) {
          debugPrint('NewsBriefDashboardCard: Server has newer data (server=$serverFetchedAt, cached=$cachedFetchedAt). Auto-refreshing...');
          final freshBriefs = await repo.forceRefreshTodaysBriefs();
          if (freshBriefs.isNotEmpty) {
            briefs = freshBriefs;
          }
        }
      } else if (briefs.isEmpty) {
        // No cached data at all — try force refresh
        final freshBriefs = await repo.forceRefreshTodaysBriefs();
        if (freshBriefs.isNotEmpty) {
          briefs = freshBriefs;
        }
      }

      final allAvailableBriefs = <NewsBrief>[];
      int activeCategories = 0;

      briefs.forEach((cat, list) {
        if (list.isNotEmpty) {
          activeCategories++;
          allAvailableBriefs.addAll(list);
        }
      });

      // Shuffle them so they roll randomly!
      allAvailableBriefs.shuffle();

      // Use the server-side edge function run time for the "Updated" label
      final effectiveTime = serverFetchedAt;

      if (mounted) {
        setState(() {
          _allBriefs = allAvailableBriefs;
          _activeBriefIndex = 0;
          _categoryCount = activeCategories;
          _isLoading = false;
          _hasError = false;
          
          if (effectiveTime != null) {
            final diff = DateTime.now().difference(effectiveTime);
            if (diff.inMinutes < 2) {
              _lastUpdatedStr = 'Updated just now';
            } else if (diff.inMinutes < 60) {
              _lastUpdatedStr = 'Updated ${diff.inMinutes} min ago';
            } else if (diff.inHours == 1) {
              _lastUpdatedStr = 'Updated 1 hour ago';
            } else if (diff.inHours < 24) {
              _lastUpdatedStr = 'Updated ${diff.inHours} hours ago';
            } else {
              _lastUpdatedStr = 'Updated ${diff.inDays}d ago';
            }
          } else {
            _lastUpdatedStr = '';
          }
        });

        // Start periodic rotation every 4 seconds
        if (allAvailableBriefs.length > 1) {
          _rotationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
            if (mounted) {
              setState(() {
                _activeBriefIndex = (_activeBriefIndex + 1) % _allBriefs.length;
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('NewsBriefDashboardCard: Error loading preview: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeNotifier.value;
    final isDark = theme.isDark;

    Widget cardContent;

    if (_isLoading) {
      cardContent = _buildLoadingState(isDark);
    } else if (_hasError) {
      cardContent = _buildErrorState(isDark);
    } else if (_allBriefs.isEmpty) {
      cardContent = _buildEmptyState(isDark);
    } else {
      cardContent = _buildLoadedState(isDark);
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewsBriefScreen()),
        ).then((_) => _loadPreviewData());
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: 100.ms,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: U.surface.withValues(alpha: isDark ? 0.4 : 0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: U.border.withValues(alpha: isDark ? 0.3 : 0.7),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: cardContent,
            ),
          ),
        ),
      ),
    ).animate()
     .fadeIn(delay: 650.ms, duration: 500.ms)
     .slideY(begin: 0.12, end: 0, delay: 650.ms, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildLoadedState(bool isDark) {
    return Row(
      children: [
        // Premium Globe Icon
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: U.primary.withValues(alpha: isDark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: U.primary.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.newspaper_rounded,
            color: U.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),

        // Text & Headline
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Today's Brief",
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 5),
              ClipRect(
                child: SizedBox(
                  height: 22,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 550),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final isEntering = (child.key as ValueKey<int>).value == _activeBriefIndex;
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: isEntering ? const Offset(0.0, 1.0) : const Offset(0.0, -1.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      key: ValueKey(_activeBriefIndex),
                      child: Text(
                        _allBriefs[_activeBriefIndex].headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: U.text.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$_categoryCount categories',
                    style: GoogleFonts.inter(
                      color: U.dim,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: TextStyle(color: U.dim.withValues(alpha: 0.5), fontSize: 10),
                  ),
                  Text(
                    _lastUpdatedStr,
                    style: GoogleFonts.inter(
                      color: U.dim,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Elegant chevron action indicator
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: U.text.withValues(alpha: isDark ? 0.08 : 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: U.text.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            color: U.text.withValues(alpha: 0.7),
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Row(
      children: [
        // Shimmering Icon Placeholder
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: U.text.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
         .shimmer(duration: 1.5.seconds, color: U.primary.withValues(alpha: 0.15)),
        const SizedBox(width: 14),

        // Shimmering Text Placeholders
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: U.text.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: U.text.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 140,
                height: 10,
                decoration: BoxDecoration(
                  color: U.text.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ).animate(onPlay: (controller) => controller.repeat())
           .shimmer(duration: 1.5.seconds, color: U.primary.withValues(alpha: 0.15)),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: U.red,
          size: 24,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Today's Brief",
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Failed to update daily news.",
                style: GoogleFonts.inter(
                  color: U.sub,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: U.primary),
          onPressed: _loadPreviewData,
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: U.dim,
          size: 24,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Today's Brief",
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "No briefings fetched for today.",
                style: GoogleFonts.inter(
                  color: U.dim,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: U.primary),
          onPressed: _loadPreviewData,
        ),
      ],
    );
  }
}
