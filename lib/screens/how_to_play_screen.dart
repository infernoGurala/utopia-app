import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        elevation: 0,
        title: Text(
          'How to Play',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: U.text),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              icon: Icons.flag_rounded,
              iconColor: U.primary,
              title: 'Objective',
              child: Text(
                'Guess the hidden science word using the clue provided each day.',
                style: GoogleFonts.outfit(
                  color: U.sub,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.rule_rounded,
              iconColor: const Color(0xFF89B4FA),
              title: 'Rules',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RuleItem(text: 'One word answer (3–6 letters)'),
                  _RuleItem(text: 'Only alphabets allowed'),
                  _RuleItem(text: 'You get limited attempts'),
                  _RuleItem(text: 'New puzzle every day'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.stars_rounded,
              iconColor: const Color(0xFFF9E2AF),
              title: 'Scoring',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RuleItem(text: '1st try: 6 pts | 2nd: 5 pts | 3rd: 4 pts'),
                  _RuleItem(text: '4th: 3 pts | 5th: 2 pts | 6th: 1 pt'),
                  _RuleItem(
                    text: 'Every completed game adds a +2 streak bonus, even on a failed round.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFF38BA8),
              title: 'Streak System',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RuleItem(text: 'Every completed game increases your streak by 1'),
                  _RuleItem(text: 'Failing all 6 tries still keeps the streak moving'),
                  _RuleItem(text: 'Missing days pauses your streak instead of resetting it'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.leaderboard_rounded,
              iconColor: const Color(0xFFA6E3A1),
              title: 'Leaderboard',
              child: Text(
                'Players are ranked by total score. If two players have the same score, the one who reached it earlier stays ahead.',
                style: GoogleFonts.outfit(
                  color: U.sub,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFF9E2AF),
              title: 'Titles System',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Special titles are shown for top players based on total score and streak performance.',
                    style: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RuleItem(
                    text:
                        'ALPHA: Rank 1 in total score and Rank 1 in streak at the same time.',
                  ),
                  _RuleItem(
                    text: 'PRIME: Rank 1 in total score.',
                  ),
                  _RuleItem(
                    text: 'FIRE: Rank 1 in current streak.',
                  ),
                  _RuleItem(
                    text: 'TOP2: Rank 2 in total score.',
                  ),
                  _RuleItem(
                    text: 'TOP3: Rank 3 in total score.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: U.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: U.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_outlined, color: U.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'New puzzle available at midnight IST',
                      style: GoogleFonts.outfit(
                        color: U.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;

  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: U.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
