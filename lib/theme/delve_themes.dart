import 'package:flutter/material.dart';
import 'delve_theme.dart';

/// 4 flower themes × 2 modes (dark + light) = 8 total themes.
///
/// PURPLE  → Wisteria     — cascading droops, deep violet energy
/// WHITE   → Bauhinia     — orchid-tree petals, dandelion wisps
/// PINK    → Sakura       — cherry blossom branches, floating petals
/// YELLOW  → Maple        — pointed autumn leaves, golden shower cascades
class DelveThemes {
  // ────────────────────────────────────────────────────
  //  DARK THEMES  (lifted backgrounds + brighter inks for visibility)
  // ────────────────────────────────────────────────────

  /// Wisteria Dark — Deepest midnight violet, vibrant lavender.
  static const wisteriaDark = DelveTheme(
    name: 'Wisteria',
    background: Color(0xFF07040F), // Dimmed from 0F0A1F
    text: Color(0xFFF3E8FF),
    botanicalInk: Color(0xFF7C3AED), 
    accent: Color(0xFFD8B4FE), 
    accentSecondary: Color(0xFF8B5CF6),
    isDark: true,
    feel: 'Midnight magic, deep and mystical.',
    flowerType: FlowerType.wisteria,
  );

  /// Bauhinia Dark — Rich obsidian with emerald energy.
  static const bauhiniaDark = DelveTheme(
    name: 'Bauhinia',
    background: Color(0xFF040807), // Dimmed from 0A1210
    text: Color(0xFFE6FFFA),
    botanicalInk: Color(0xFF059669), 
    accent: Color(0xFF34D399), 
    accentSecondary: Color(0xFF10B981),
    isDark: true,
    feel: 'Deep forest sanctuary, crisp and alive.',
    flowerType: FlowerType.bauhinia,
  );

  /// Sakura Dark — Darkest burgundy with rose-gold glow.
  static const sakuraDark = DelveTheme(
    name: 'Sakura',
    background: Color(0xFF0D060A), // Dimmed from 1A0D14
    text: Color(0xFFFFF1F2),
    botanicalInk: Color(0xFFE11D48), 
    accent: Color(0xFFFB7185), 
    accentSecondary: Color(0xFFF43F5E),
    isDark: true,
    feel: 'Moonlit blossoms, warm and romantic.',
    flowerType: FlowerType.sakura,
  );

  /// Maple Dark — Obsidian brown with molten gold.
  static const mapleDark = DelveTheme(
    name: 'Maple',
    background: Color(0xFF080706), // Dimmed from 120F0D
    text: Color(0xFFFFFBEB),
    botanicalInk: Color(0xFFB45309), 
    accent: Color(0xFFFBBF24), 
    accentSecondary: Color(0xFFF59E0B),
    isDark: true,
    feel: 'Autumn fireplace, warm and intense.',
    flowerType: FlowerType.maple,
  );

  // ────────────────────────────────────────────────────
  //  LIGHT THEMES (Premium High Contrast - Dimmed)
  // ────────────────────────────────────────────────────

  /// Wisteria Light — Softest violet mist.
  static const wisteriaLight = DelveTheme(
    name: 'Wisteria',
    background: Color(0xFFE5E5F2), // Dimmed from FAFAFF
    text: Color(0xFF1E1B4B),
    botanicalInk: Color(0xFF8B5CF6),
    accent: Color(0xFF6D28D9), 
    accentSecondary: Color(0xFF4C1D95),
    isDark: false,
    feel: 'Clean, literary, sophisticated.',
    flowerType: FlowerType.wisteria,
  );

  /// Bauhinia Light — Pure mineral white with forest accents.
  static const bauhiniaLight = DelveTheme(
    name: 'Bauhinia',
    background: Color(0xFFD6EAE0), // Dimmed from F0FDF4
    text: Color(0xFF064E3B),
    botanicalInk: Color(0xFF10B981),
    accent: Color(0xFF047857), 
    accentSecondary: Color(0xFF065F46),
    isDark: false,
    feel: 'Fresh, organic, refined.',
    flowerType: FlowerType.bauhinia,
  );

  /// Sakura Light — Pearl rose.
  static const sakuraLight = DelveTheme(
    name: 'Sakura',
    background: Color(0xFFE8D6D9), // Dimmed from FFF1F2
    text: Color(0xFF881337),
    botanicalInk: Color(0xFFF43F5E),
    accent: Color(0xFFBE123C), 
    accentSecondary: Color(0xFF9F1239),
    isDark: false,
    feel: 'Artistic, vibrant, spring morning.',
    flowerType: FlowerType.sakura,
  );

  /// Maple Light — Warm parchment with deep amber.
  static const mapleLight = DelveTheme(
    name: 'Maple',
    background: Color(0xFFE8E2D1), // Dimmed from FFFBEB
    text: Color(0xFF451A03),
    botanicalInk: Color(0xFFD97706),
    accent: Color(0xFFB45309), 
    accentSecondary: Color(0xFF92400E),
    isDark: false,
    feel: 'Grounded, classic, warm paper.',
    flowerType: FlowerType.maple,
  );

  /// Ordered: dark first, then light. Within each mode: purple, white, pink, yellow.
  static const List<DelveTheme> all = [
    wisteriaDark,
    bauhiniaDark,
    sakuraDark,
    mapleDark,
    wisteriaLight,
    bauhiniaLight,
    sakuraLight,
    mapleLight,
  ];

  static List<DelveTheme> get darkThemes => all.where((t) => t.isDark).toList();
  static List<DelveTheme> get lightThemes => all.where((t) => !t.isDark).toList();

  static DelveTheme getByName(String name) {
    return all.firstWhere((t) => t.name == name, orElse: () => wisteriaDark);
  }

  /// Get a theme by name + mode. Since names repeat across light/dark,
  /// this finds the correct variant.
  static DelveTheme getByNameAndMode(String name, bool isDark) {
    return all.firstWhere(
      (t) => t.name == name && t.isDark == isDark,
      orElse: () => wisteriaDark,
    );
  }
}
