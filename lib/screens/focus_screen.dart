import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import 'daily_note_screen.dart';
import 'heatmap_home_screen.dart';
import 'reminders_screen.dart';
import '../services/focus_supabase_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _service = FocusSupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _streakInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _service.initialize();
      final info = await _service.getBestActiveStreak();
      if (mounted) {
        setState(() {
          _streakInfo = info;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Utopia',
                style: GoogleFonts.playfairDisplay(
                  color: U.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                      color: U.text.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Stay productive and track your habits',
                style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
            ),

            if (_streakInfo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Streak',
                              style: GoogleFonts.outfit(color: U.primary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${_streakInfo!['task_name']} — ${_streakInfo!['streak']} days',
                              style: GoogleFonts.outfit(color: U.primary, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              ),

            const SizedBox(height: 32),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: U.primary),
                ),
              )
            else
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _FocusCard(
                      title: 'Daily Note',
                      icon: Icons.edit_document,
                      color: U.primary,
                      delay: 100,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DailyNoteScreen()),
                      ).then((_) => _loadData()),
                    ),
                    _FocusCard(
                      title: 'Activity',
                      icon: Icons.grid_view_rounded,
                      color: U.peach,
                      delay: 150,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HeatmapHomeScreen()),
                      ).then((_) => _loadData()),
                    ),
                    _FocusCard(
                      title: 'Reminders',
                      icon: Icons.notifications_outlined,
                      color: const Color(0xFF7C6AF7),
                      delay: 200,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RemindersScreen()),
                      ).then((_) => _loadData()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int delay;

  const _FocusCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: delay.ms, duration: 500.ms).slideY(
            begin: 0.1,
            end: 0,
            delay: delay.ms,
            duration: 500.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
