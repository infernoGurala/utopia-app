import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'friends_screen.dart';

class UniversityScreen extends StatefulWidget {
  const UniversityScreen({super.key});

  @override
  State<UniversityScreen> createState() => _UniversityScreenState();
}

class _UniversityScreenState extends State<UniversityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.index = 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildComingSoon() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, color: U.dim, size: 64),
          const SizedBox(height: 16),
          Text(
            'Coming Soon',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature is under development',
            style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: U.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: U.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      labelColor: U.bg,
                      unselectedLabelColor: U.sub,
                      indicator: BoxDecoration(
                        color: U.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(999),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Friends'),
                        Tab(text: 'Community'),
                        Tab(text: 'Events'),
                        Tab(text: 'Everyone'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const FriendsScreen(),
          _buildComingSoon(),
          _buildComingSoon(),
          _buildComingSoon(),
        ],
      ),
    );
  }
}
