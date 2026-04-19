import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';


const LinearGradient _legendGradient = LinearGradient(
  colors: [
    Color(0xFFF6D68A),
    Color(0xFFE9BC62),
    Color(0xFFD89B45),
    Color(0xFFB7792F),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _goatGradient = LinearGradient(
  colors: [
    Color(0xFFE58D6F),
    Color(0xFFD86E4B),
    Color(0xFFBF593B),
    Color(0xFF8F412E),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _topDogGradient = LinearGradient(
  colors: [
    Color(0xFFF2D189),
    Color(0xFFE1A95C),
    Color(0xFFC97B4B),
    Color(0xFF9D5A35),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _sapphireGradient = LinearGradient(
  colors: [
    Color(0xFF9FB8D9),
    Color(0xFF7A9CC7),
    Color(0xFF5E7FA8),
    Color(0xFF425D82),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _silverGradient = LinearGradient(
  colors: [
    Color(0xFFD7D7DB),
    Color(0xFFB8BAC3),
    Color(0xFF9498A4),
    Color(0xFF6D7280),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

enum ChampionType { topDog, legend, goat, sapphire, silver, none }

ChampionType _typeFromScoreAndStreakRank(
  int? scoreRank,
  int? streakRank, {
  String? email,
}) {
  if (scoreRank == null && streakRank == null) return ChampionType.none;

  final isTopScore = scoreRank != null && scoreRank <= 3;
  final isTopStreak = streakRank != null && streakRank == 1;
  final isTopScoreRank1 = scoreRank != null && scoreRank == 1;

  if (isTopScoreRank1 && isTopStreak) return ChampionType.topDog;
  if (isTopStreak) return ChampionType.goat;
  if (isTopScoreRank1) return ChampionType.legend;
  if (isTopScore && scoreRank == 2) return ChampionType.sapphire;
  if (isTopScore && scoreRank == 3) return ChampionType.silver;

  return ChampionType.none;
}

LinearGradient _gradientForType(ChampionType type) => switch (type) {
  ChampionType.topDog => _topDogGradient,
  ChampionType.legend => _legendGradient,
  ChampionType.goat => _goatGradient,
  ChampionType.sapphire => _sapphireGradient,
  ChampionType.silver => _silverGradient,
  ChampionType.none => _topDogGradient,
};

Color _accentForType(ChampionType type) => switch (type) {
  ChampionType.topDog => const Color(0xFFE8B85C),
  ChampionType.legend => const Color(0xFFF0C86D),
  ChampionType.goat => const Color(0xFFD97857),
  ChampionType.sapphire => const Color(0xFF7F9DC5),
  ChampionType.silver => const Color(0xFFB7BBC6),
  ChampionType.none => const Color(0xFFE8B85C),
};

Color _darkBgForType(ChampionType type) => switch (type) {
  ChampionType.topDog => const Color(0xFF1F1A05),
  ChampionType.legend => const Color(0xFF1F1A05),
  ChampionType.goat => const Color(0xFF1A0A00),
  ChampionType.sapphire => const Color(0xFF0A1929),
  ChampionType.silver => const Color(0xFF1A1A1A),
  ChampionType.none => const Color(0xFF17131D),
};

String _labelForType(ChampionType type) => switch (type) {
  ChampionType.topDog => 'ALPHA',
  ChampionType.legend => 'PRIME',
  ChampionType.goat => 'FIRE',
  ChampionType.sapphire => 'TOP2',
  ChampionType.silver => 'TOP3',
  ChampionType.none => '',
};

IconData _iconForType(ChampionType type) => switch (type) {
  ChampionType.topDog => Icons.local_fire_department_rounded,
  ChampionType.legend => Icons.workspace_premium_rounded,
  ChampionType.goat => Icons.whatshot_rounded,
  ChampionType.sapphire => Icons.star_rounded,
  ChampionType.silver => Icons.star_rounded,
  ChampionType.none => Icons.star_rounded,
};

class GameChampionStar extends StatelessWidget {
  const GameChampionStar({
    super.key,
    this.size = 16,
    this.glow = true,
    this.type = ChampionType.legend,
  });

  final double size;
  final bool glow;
  final ChampionType type;

  @override
  Widget build(BuildContext context) {
    final frameSize = size + 14;
    final shouldGlow =
        glow &&
        (type == ChampionType.legend ||
            type == ChampionType.goat ||
            type == ChampionType.topDog);
    return Container(
      width: frameSize,
      height: frameSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _darkBgForType(type).withValues(alpha: 0.94),
            const Color(0xFF17131D),
          ],
        ),
        border: Border.all(
          color: _accentForType(type).withValues(alpha: 0.82),
          width: 1.2,
        ),
        boxShadow: shouldGlow
            ? [
                BoxShadow(
                  color: _accentForType(type).withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 0.6,
                ),
                BoxShadow(
                  color: _accentForType(type).withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) =>
              _gradientForType(type).createShader(bounds),
          child: Icon(
            _iconForType(type),
            size: size,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ChampionNameText extends StatelessWidget {
  const ChampionNameText({
    super.key,
    required this.name,
    this.scoreRank,
    this.streakRank,
    this.email,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.isSuperUser = false,
  });

  final String name;
  final int? scoreRank;
  final int? streakRank;
  final String? email;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;
  final bool isSuperUser;

  ChampionType get _type =>
      _typeFromScoreAndStreakRank(scoreRank, streakRank, email: email);

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ??
        GoogleFonts.outfit(
          color: U.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _type != ChampionType.none
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final shaderBounds = Rect.fromLTWH(
                      0,
                      0,
                      constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : ((baseStyle.fontSize ?? 14) * name.length * 0.72),
                      (baseStyle.fontSize ?? 14) * maxLines * 1.5,
                    );
                    return Text(
                      name,
                      maxLines: maxLines,
                      overflow: overflow,
                      style: baseStyle.copyWith(
                        color: null,
                        fontWeight: FontWeight.w700,
                        foreground: Paint()
                          ..shader = _gradientForType(
                            _type,
                          ).createShader(shaderBounds),
                        shadows: [
                          Shadow(
                            color: _accentForType(
                              _type,
                            ).withValues(alpha: 0.16),
                            blurRadius: 6,
                          ),
                        ],
                        letterSpacing: 0.1,
                      ),
                    );
                  },
                )
              : Text(
                  name,
                  maxLines: maxLines,
                  overflow: overflow,
                  style: baseStyle,
                ),
        ),
        if (isSuperUser) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Super User',
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF0095F6),
              size: 16,
            ),
          ),
        ],
        if (_type != ChampionType.none) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  _darkBgForType(_type).withValues(alpha: 0.96),
                  const Color(0xFF1A1520).withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(
                color: _accentForType(_type).withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentForType(_type).withValues(alpha: 0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              _labelForType(_type),
              style: GoogleFonts.outfit(
                color: _accentForType(_type),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ChampionAvatarBadge extends StatelessWidget {
  const ChampionAvatarBadge({
    super.key,
    required this.child,
    this.scoreRank,
    this.streakRank,
    this.email,
    this.showGlow = true,
  });

  final Widget child;
  final int? scoreRank;
  final int? streakRank;
  final String? email;
  final bool showGlow;

  ChampionType get _type =>
      _typeFromScoreAndStreakRank(scoreRank, streakRank, email: email);

  @override
  Widget build(BuildContext context) {
    if (_type == ChampionType.none) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow:
                showGlow &&
                    (_type == ChampionType.legend ||
                        _type == ChampionType.goat ||
                        _type == ChampionType.topDog)
                ? [
                    BoxShadow(
                      color: _accentForType(_type).withValues(alpha: 0.2),
                      blurRadius: 14,
                      spreadRadius: 0.8,
                    ),
                    BoxShadow(
                      color: _accentForType(_type).withValues(alpha: 0.1),
                      blurRadius: 22,
                      spreadRadius: 0.2,
                    ),
                  ]
                : null,
            gradient: SweepGradient(
              colors: [
                _accentForType(_type).withValues(alpha: 0.92),
                _gradientForType(_type).colors[1],
                _gradientForType(_type).colors[3],
                _gradientForType(_type).colors[2],
                _accentForType(_type).withValues(alpha: 0.92),
              ],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1B1622).withValues(alpha: 0.9),
                width: 1.4,
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
