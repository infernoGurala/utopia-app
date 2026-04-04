import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../models/sciwordle_model.dart';
import '../services/sciwordle_service.dart';

const LinearGradient _goldGradient = LinearGradient(
  colors: [
    Color(0xFFF5D48A),
    Color(0xFFE0B25A),
    Color(0xFFBD8541),
    Color(0xFF8B5B2F),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _sapphireGradient = LinearGradient(
  colors: [
    Color(0xFFA9BEDC),
    Color(0xFF7E9EC8),
    Color(0xFF5C7BA2),
    Color(0xFF425C81),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _roseGradient = LinearGradient(
  colors: [
    Color(0xFFD8C1D9),
    Color(0xFFBC9CBF),
    Color(0xFF97799C),
    Color(0xFF6E5874),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

LinearGradient _gradientForRank(int rank) => switch (rank) {
  1 => _goldGradient,
  2 => _sapphireGradient,
  3 => _roseGradient,
  _ => _goldGradient,
};

Color _accentForRank(int rank) => switch (rank) {
  1 => const Color(0xFFE4B868),
  2 => const Color(0xFF87A5CC),
  3 => const Color(0xFFB194B6),
  _ => const Color(0xFFE4B868),
};

Color _darkBgForRank(int rank) => switch (rank) {
  1 => const Color(0xFF1A1206),
  2 => const Color(0xFF0A1929),
  3 => const Color(0xFF1A0A1A),
  _ => const Color(0xFF17131D),
};

class SciwordleLeaderboardScreen extends StatefulWidget {
  const SciwordleLeaderboardScreen({super.key});

  @override
  // ignore: invalid_override
  createState() => _SciwordleLeaderboardScreenState();
}

class _SciwordleLeaderboardScreenState
    extends State<SciwordleLeaderboardScreen> {
  final SciwordleService _service = SciwordleService();

  bool _loading = true;
  String? _error;
  List<SciwordleLeaderboardEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.fetchLeaderboard();

      setState(() {
        _entries = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load leaderboard';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        elevation: 0,
        title: Text(
          'SciWordle Leaderboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: U.text),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: U.primary),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(currentUid),
    );
  }

  Widget _buildBody(String? currentUid) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: GoogleFonts.outfit(color: U.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, color: U.dim, size: 64),
            const SizedBox(height: 16),
            Text(
              'No scores yet',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Play SciWordle to get on the leaderboard!',
              style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final isMe = entry.uid == currentUid;

              return _LeaderboardTile(index: index, entry: entry, isMe: isMe);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: U.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => _goldGradient.createShader(bounds),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_entries.length} players',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Ranked by total score',
                style: GoogleFonts.outfit(color: U.dim, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                'Earlier scorer wins ties',
                style: GoogleFonts.outfit(color: U.sub, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int index;
  final SciwordleLeaderboardEntry entry;
  final bool isMe;

  const _LeaderboardTile({
    required this.index,
    required this.entry,
    required this.isMe,
  });

  bool get _isTop3 => index <= 2;
  int get _rank => index + 1;

  @override
  Widget build(BuildContext context) {
    if (_isTop3) {
      return _PremiumTile(
        rank: _rank,
        name: entry.name,
        totalScore: entry.totalScore,
        streak: entry.streak,
        isMe: isMe,
      );
    }

    return _NormalTile(
      index: index,
      name: entry.name,
      totalScore: entry.totalScore,
      streak: entry.streak,
      isMe: isMe,
    );
  }
}

class _PremiumTile extends StatelessWidget {
  const _PremiumTile({
    required this.rank,
    required this.name,
    required this.totalScore,
    required this.streak,
    required this.isMe,
  });

  final int rank;
  final String name;
  final int totalScore;
  final int streak;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            _gradientForRank(rank).colors.first.withValues(alpha: 0.9),
            _gradientForRank(rank).colors.last.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _darkBgForRank(rank),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    _accentForRank(rank).withValues(alpha: 0.24),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _accentForRank(rank).withValues(alpha: 0.45),
                ),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: GoogleFonts.outfit(
                    color: _accentForRank(rank),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _accentForRank(
                                rank,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'YOU',
                            style: GoogleFonts.outfit(
                              color: _accentForRank(rank),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.stars_rounded,
                        label: '$totalScore pts',
                        textColor: Colors.white,
                        tint: _accentForRank(rank),
                      ),
                      _MetaPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '$streak streak',
                        textColor: U.sub,
                        tint: _accentForRank(rank),
                      ),
                    ],
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

class _NormalTile extends StatelessWidget {
  const _NormalTile({
    required this.index,
    required this.name,
    required this.totalScore,
    required this.streak,
    required this.isMe,
  });

  final int index;
  final String name;
  final int totalScore;
  final int streak;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? U.primary.withValues(alpha: 0.08) : U.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? U.primary.withValues(alpha: 0.5) : U.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: U.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.outfit(
                  color: U.dim,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: U.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.outfit(
                            color: U.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaPill(
                      icon: Icons.stars_rounded,
                      label: '$totalScore pts',
                      textColor: U.text,
                      tint: U.primary,
                    ),
                    _MetaPill(
                      icon: Icons.local_fire_department_rounded,
                      label: '$streak streak',
                      textColor: U.sub,
                      tint: const Color(0xFFF38BA8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color textColor;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
