import 'dart:ui';
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
  NewsBrief? _previewBrief;
  int _categoryCount = 0;
  String _lastUpdatedStr = 'Updated just now';

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
  }

  Future<void> _loadPreviewData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final briefs = await NewsBriefRepository().getTodaysBriefs();
      
      NewsBrief? topBrief;
      int activeCategories = 0;

      // Find the first brief available in any category as a preview
      final categoryOrder = ['india', 'world', 'tech', 'economy', 'sports', 'culture'];
      for (final cat in categoryOrder) {
        if (briefs.containsKey(cat) && briefs[cat]!.isNotEmpty) {
          activeCategories++;
          topBrief ??= briefs[cat]!.first;
        }
      }

      // Check others too in case
      briefs.forEach((cat, list) {
        if (!categoryOrder.contains(cat) && list.isNotEmpty) {
          activeCategories++;
          topBrief ??= list.first;
        }
      });

      if (mounted) {
        setState(() {
          _previewBrief = topBrief;
          _categoryCount = activeCategories;
          _isLoading = false;
          _hasError = false;
          
          final localBrief = topBrief;
          if (localBrief != null) {
            final now = DateTime.now();
            final diff = now.difference(localBrief.publishedAt);
            if (diff.inHours <= 0) {
              _lastUpdatedStr = 'Updated just now';
            } else if (diff.inHours == 1) {
              _lastUpdatedStr = 'Updated 1 hour ago';
            } else {
              _lastUpdatedStr = 'Updated ${diff.inHours} hours ago';
            }
          } else {
            _lastUpdatedStr = 'Updated just now';
          }
        });
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
    } else if (_previewBrief == null) {
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
            Icons.language_rounded,
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
              Text(
                _previewBrief!.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: U.text.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 14.5,
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
