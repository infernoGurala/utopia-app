import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/sciwordle_service.dart';

class SciwordleStatsScreen extends StatefulWidget {
  const SciwordleStatsScreen({super.key});

  @override
  State<SciwordleStatsScreen> createState() => _SciwordleStatsScreenState();
}

class _SciwordleStatsScreenState extends State<SciwordleStatsScreen> {
  final SciwordleService _service = SciwordleService();
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  Map<String, int> _guessDistribution = {
    '1': 0,
    '2': 0,
    '3': 0,
    '4': 0,
    '5': 0,
    '6': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final score = await _service.fetchPlayerScore();
      final leaderboard = await _service.fetchLeaderboard();

      int gamesWon = 0;
      for (final entry in leaderboard) {
        if (entry.uid == score.uid) {
          gamesWon = entry.gamesPlayed;
          break;
        }
      }

      setState(() {
        _stats = {
          'gamesPlayed': score.gamesPlayed,
          'gamesWon': gamesWon,
          'currentStreak': score.streak,
          'maxStreak': score.bestStreak,
          'totalScore': score.totalScore,
        };
        _guessDistribution = score.guessDistribution;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        elevation: 0,
        title: Text(
          'Statistics',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: U.text),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: U.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final gamesPlayed = _stats['gamesPlayed'] ?? 0;
    final gamesWon = _stats['gamesWon'] ?? 0;
    final winPercent = gamesPlayed > 0
        ? ((gamesWon / gamesPlayed) * 100).round()
        : 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildStatRow(gamesPlayed, gamesWon, winPercent),
        const SizedBox(height: 24),
        _buildGuessDistribution(),
        const SizedBox(height: 24),
        _buildNextPuzzle(),
      ],
    );
  }

  Widget _buildStatRow(int played, int won, int percent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('$played', 'Played'),
          _buildDivider(),
          _buildStatItem('$won', 'Won'),
          _buildDivider(),
          _buildStatItem('$percent%', 'Win %'),
          _buildDivider(),
          _buildStatItem('${_stats['currentStreak'] ?? 0}', 'Streak'),
          _buildDivider(),
          _buildStatItem('${_stats['maxStreak'] ?? 0}', 'Max'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: U.sub,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: U.border);
  }

  Widget _buildGuessDistribution() {
    final maxValue = _guessDistribution.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guess Distribution',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(6, (i) {
            final count = _guessDistribution['${i + 1}'] ?? 0;
            final percent = maxValue > 0 ? (count / maxValue) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth * percent;
                        return Stack(
                          children: [
                            Container(
                              width: width.clamp(30, constraints.maxWidth),
                              height: 28,
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? const Color(0xFF4ADE80)
                                    : U.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '$count',
                                style: GoogleFonts.outfit(
                                  color: count > 0 ? Colors.white : U.dim,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNextPuzzle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Puzzle Drops',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Morning Edition', '1:00 AM - 2:00 AM IST', Icons.wb_twilight_rounded),
          const SizedBox(height: 8),
          _buildInfoRow('Afternoon Edition', '11:00 AM - 12:00 PM IST', Icons.wb_sunny_rounded),
          const SizedBox(height: 8),
          _buildInfoRow('Evening Edition', '4:00 PM - 5:00 PM IST', Icons.nights_stay_rounded),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: U.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            time,
            style: GoogleFonts.outfit(
              color: U.sub,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


}
