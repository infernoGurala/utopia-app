import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../models/news_brief.dart';
import '../models/news_category.dart';
import '../services/news_brief_repository.dart';
import '../widgets/utopia_loader.dart';

class NewsBriefScreen extends StatefulWidget {
  const NewsBriefScreen({super.key});

  @override
  State<NewsBriefScreen> createState() => _NewsBriefScreenState();
}

class _NewsBriefScreenState extends State<NewsBriefScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, List<NewsBrief>> _briefs = {};
  int _currentTab = 0;
  late final PageController _pageController;
  final ScrollController _tabsScrollController = ScrollController();

  List<NewsCategory> _categories = [
    NewsCategory(slug: 'world', label: 'World', displayOrder: 1),
    NewsCategory(slug: 'tech', label: 'Tech', displayOrder: 2),
    NewsCategory(slug: 'ai', label: 'AI', displayOrder: 3),
    NewsCategory(slug: 'science', label: 'Science', displayOrder: 4),
    NewsCategory(slug: 'india', label: 'India', displayOrder: 5),
    NewsCategory(slug: 'movies', label: 'Movies', displayOrder: 6),
    NewsCategory(slug: 'entertainment', label: 'Entertainment', displayOrder: 7),
    NewsCategory(slug: 'social_media', label: 'Social Media', displayOrder: 8),
    NewsCategory(slug: 'sports', label: 'Sports', displayOrder: 9),
    NewsCategory(slug: 'politics', label: 'Politics', displayOrder: 10),
    NewsCategory(slug: 'economy', label: 'Economy', displayOrder: 11),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTab);
    _loadNewsBriefs();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabsScrollController.dispose();
    super.dispose();
  }

  void _scrollToTab(int index) {
    if (!_tabsScrollController.hasClients) return;
    
    // Smoothly centers the selected category tab horizontally in the viewport
    final double chipWidth = 110.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    double target = (index * chipWidth) + 16.0 - (screenWidth / 2) + (chipWidth / 2);
    
    final double maxScroll = _tabsScrollController.position.maxScrollExtent;
    if (target < 0) target = 0;
    if (target > maxScroll) target = maxScroll;
    
    _tabsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadNewsBriefs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final categories = await NewsBriefRepository().getActiveCategories();
      final briefs = await NewsBriefRepository().forceRefreshTodaysBriefs();

      // Filter out any NewsBrief where headline is empty or null before displaying cards
      final Map<String, List<NewsBrief>> filteredBriefs = {};
      briefs.forEach((key, list) {
        filteredBriefs[key] = list.where((brief) {
          return brief.headline.trim().isNotEmpty;
        }).toList();
      });

      // Exclude categories that have no news briefs today to hide empty tabs from top menu
      final filteredCategories = categories.where((cat) {
        final list = filteredBriefs[cat.slug];
        return list != null && list.isNotEmpty;
      }).toList();

      if (mounted) {
        setState(() {
          _categories = filteredCategories;
          _briefs = filteredBriefs;
          if (_currentTab >= _categories.length) {
            _currentTab = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(0);
              }
            });
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('NewsBriefScreen: Error fetching briefs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekday = weekdays[now.weekday % 7];
    final month = months[now.month - 1];
    return '$weekday, ${now.day} $month';
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeNotifier.value;
    final isDark = theme.isDark;

    Widget bodyContent;

    if (_isLoading) {
      bodyContent = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UtopiaLoader(scale: 0.8),
            const SizedBox(height: 16),
            Text(
              'Assembling briefings...',
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (_hasError) {
      bodyContent = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: U.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load briefings',
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please check your internet connection',
              style: GoogleFonts.inter(color: U.sub, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loadNewsBriefs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_categories.isEmpty) {
      bodyContent = RefreshIndicator(
        color: U.primary,
        backgroundColor: U.card,
        onRefresh: _loadNewsBriefs,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            _buildEmptyState('Today'),
          ],
        ),
      );
    } else {
      bodyContent = Column(
        children: [
          const SizedBox(height: 14),
          // Horizontal category selection chips
          _buildCategoryTabs(isDark),
          const SizedBox(height: 10),

          // Sliding PageView for independent category listings
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentTab = index;
                });
                _scrollToTab(index);
              },
              itemCount: _categories.length,
              itemBuilder: (context, catIndex) {
                final catKey = _categories[catIndex].slug;
                final list = _briefs[catKey] ?? [];

                if (list.isEmpty) {
                  return _buildEmptyState(_categories[catIndex].label);
                }

                return RefreshIndicator(
                  color: U.primary,
                  backgroundColor: U.card,
                  onRefresh: _loadNewsBriefs,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final brief = list[index];
                      return _buildNewsCard(brief, isDark)
                          .animate()
                          .fadeIn(
                            delay: (index * 80).ms, 
                            duration: 400.ms,
                          )
                          .slideY(
                            begin: 0.08, 
                            end: 0, 
                            delay: (index * 80).ms, 
                            duration: 400.ms, 
                            curve: Curves.easeOutCubic,
                          );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getFormattedDate(),
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              "Today's Brief",
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: U.text),
            onPressed: _loadNewsBriefs,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        controller: _tabsScrollController,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _currentTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentTab = index;
                });
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                );
                _scrollToTab(index);
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? U.primary 
                      : U.surface.withValues(alpha: isDark ? 0.35 : 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected 
                        ? U.primary 
                        : U.border.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected 
                          ? U.primary.withValues(alpha: 0.2) 
                          : Colors.transparent,
                      blurRadius: isSelected ? 8 : 0,
                      offset: isSelected ? const Offset(0, 2) : Offset.zero,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    _categories[index].label,
                    style: GoogleFonts.outfit(
                      color: isSelected ? U.bg : U.text,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewsCard(NewsBrief brief, bool isDark) {
    final hasImage = brief.imageUrl != null && brief.imageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: U.surface.withValues(alpha: isDark ? 0.35 : 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: U.border.withValues(alpha: isDark ? 0.3 : 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: brief.imageUrl!.trim(),
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 170,
                color: U.border.withValues(alpha: 0.05),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: U.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meta row: Source & Published time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: U.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.star_rounded, size: 10, color: U.primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      brief.sourceName,
                      style: GoogleFonts.inter(
                        color: U.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: TextStyle(color: U.dim.withValues(alpha: 0.4), fontSize: 10),
                    ),
                    Text(
                      _timeAgo(brief.publishedAt),
                      style: GoogleFonts.inter(
                        color: U.dim,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Headline Text
                Text(
                  brief.headline,
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                
                Divider(color: U.border.withValues(alpha: 0.4), height: 24, thickness: 0.8),

                // Curated Key Fact Block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: U.primary.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: U.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.35,
                            ),
                            children: [
                              TextSpan(
                                text: 'KEY FACT: ',
                                style: GoogleFonts.inter(
                                  color: U.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: brief.keyFact,
                                style: GoogleFonts.inter(
                                  color: U.text.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // AI Summary
                Text(
                  brief.summary,
                  style: GoogleFonts.inter(
                    color: U.sub,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String categoryLabel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: U.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.newspaper_rounded,
                color: U.primary.withValues(alpha: 0.6),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No briefs in $categoryLabel',
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for fresh AI-curated news briefs.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: U.dim,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
