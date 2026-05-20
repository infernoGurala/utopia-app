import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// IMAGE OVERLAY COLORS
/// ─────────────────────────────────────────────────────────────────────────────
/// Colors for ALL text that sits on or near the background image:
///   • title    → "Utopia" / "University" / "Semesters"
///   • subtitle → tagline below title
///   • greeting → "Good morning, Name"  (sits in gradient transition zone)
///   • quote    → motivational text below greeting
///
/// Structure:
///   themeKey → { 'morning' | 'afternoon' | 'evening' | 'night' } → _Quad
///
/// HOW TO CUSTOMISE
/// ──────────────────
/// Edit the Color values below. Hot-reload is enough.
///
/// Themes and their keys:
///   'catppuccin-latte'   Catppuccin Latte  (light)
///   'rose-pine-dawn'     Rosé Pine Dawn    (light)
///   'mint-light'         Mint Light        (light)
///   'one-light'          One Light         (light)
///   'orchid'             Orchid            (dark)
///   'gruvbox'            Gruvbox           (dark)
///   'everforest'         Everforest        (dark)
///   'github-dark'        GitHub Dark       (dark)
/// ─────────────────────────────────────────────────────────────────────────────

class ImageOverlayColors {
  // ── Catppuccin Latte ── (light theme)
  //                        title                subtitle             greeting             quote
  static const _catppuccinLatte = {
    'morning':   _Quad(Color(0xFF211047), Color(0xFF141438), Color(0xFF110826), Color(0xFF1F0F42)),
    'afternoon': _Quad(Color(0xFF211047), Color(0xFF141438), Color(0xFF110826), Color(0xFF1F0F42)),
    'evening':   _Quad(Color(0xFFFEE8D6), Color(0xFFF2D1BA), Color(0xFFFFFFFF), Color(0xFFFEE8D6)),
    'night':     _Quad(Color(0xFFE8E5F8), Color(0xFFCAC5E8), Color(0xFFFFFFFF), Color(0xFFE8E5F8)),
  };

  // ── Rosé Pine Dawn ── (light theme)
  static const _rosePineDawn = {
    'morning':   _Quad(Color(0xFF8F2A43), Color(0xFF191724), Color(0xFF191724), Color(0xFF191724)),
    'afternoon': _Quad(Color(0xFF8F2A43), Color(0xFF191724), Color(0xFF191724), Color(0xFF191724)),
    'evening':   _Quad(Color(0xFFFEE9E7), Color(0xFFF8CFCB), Color(0xFFFFFFFF), Color(0xFFFEE9E7)),
    'night':     _Quad(Color(0xFFFAD1CE), Color(0xFFE8DCDA), Color(0xFFFFFFFF), Color(0xFFFAF4ED)),
  };

  // ── Mint Light ── (light theme)
  static const _mintLight = {
    'morning':   _Quad(Color(0xFF072B1F), Color(0xFF0C2B22), Color(0xFF021A12), Color(0xFF043022)),
    'afternoon': _Quad(Color(0xFF072B1F), Color(0xFF0C2B22), Color(0xFF021A12), Color(0xFF043022)),
    'evening':   _Quad(Color(0xFFD5F3E5), Color(0xFFAFE0C9), Color(0xFFFFFFFF), Color(0xFFD5F3E5)),
    'night':     _Quad(Color(0xFFD1F2E2), Color(0xFFA3DFBE), Color(0xFFFFFFFF), Color(0xFFF2FBF7)),
  };

  // ── One Light ── (light theme)
  static const _oneLight = {
    'morning':   _Quad(Color(0xFF0D2554), Color(0xFF2A2B33), Color(0xFF0A0C14), Color(0xFF2A2B33)),
    'afternoon': _Quad(Color(0xFF0D2554), Color(0xFF1F1F1F), Color(0xFF0A0C14), Color(0xFF1F1F1F)),
    'evening':   _Quad(Color(0xFFE6EDFF), Color(0xFFB8CDFF), Color(0xFFFFFFFF), Color(0xFFE6EDFF)),
    'night':     _Quad(Color(0xFFE3EAFA), Color(0xFFB4C8FA), Color(0xFFFFFFFF), Color(0xFFFAFAFA)),
  };

  // ── Orchid ── (dark theme)  — null greeting/quote → falls back to U.text/U.sub
  static const _orchid = {
    'morning':   _Quad(Color(0xFF2D1A47), Color(0xFF230947), Color(0xFF220345), Color(0xFF220345)),
    'afternoon': _Quad(Color(0xFF2D1A47), Color(0xFF230947), Color(0xFF220345), Color(0xFF220345)),
    'evening':   _Quad(Color(0xFFCBA6F7), Color(0xFFB4BEFE), Color(0xFFE8D5FF), Color(0xFFB3A3D0)),
    'night':     _Quad(Color(0xFFCBA6F7), Color(0xFFB4BEFE), Color(0xFFF1E8FF), Color(0xFFC5B8E2)),
  };

  // ── Gruvbox ── (dark theme)
  static const _gruvbox = {
    'morning':   _Quad(Color(0xFF260900), Color(0xFF292821), Color(0xFF211600), Color(0xFF292821)),
    'afternoon': _Quad(Color(0xFF260900), Color(0xFF292821), Color(0xFF211600), Color(0xFF292821)),
    'evening':   _Quad(Color(0xFFFE8019), Color(0xFFA89984), Color(0xFFEBDBB2), Color(0xFFBDAE93)),
    'night':     _Quad(Color(0xFFFB4934), Color(0xFFEBDBB2), Color(0xFFFBF1C7), Color(0xFFD5C4A1)),
  };

  // ── Everforest ── (dark theme)
  static const _everforest = {
    'morning':   _Quad(Color(0xFF1D3000), Color(0xFF131C04),  Color(0xFF111C00),  Color(0xFF111C00)),
    'afternoon': _Quad(Color(0xFF1D3000), Color(0xFF131C04),  Color(0xFF111C00),  Color(0xFF111C00)),
    'evening':   _Quad(Color(0xFFA7C080), Color(0xFFD3C6AA), Color(0xFFE6E2CC), Color(0xFFD3C6AA)),
    'night':     _Quad(Color(0xFFA7C080), Color(0xFFD3C6AA), Color(0xFFFDF6E3), Color(0xFFE6E2CC)),
  };

  // ── GitHub Dark ── (dark theme)
  static const _githubDark = {
    'morning':   _Quad(Color(0xFF0B213B), Color(0xFF132A45), Color(0xFF0B213B), Color(0xFF0B213B)),
    'afternoon': _Quad(Color(0xFF0B213B), Color(0xFF132A45), Color(0xFF0B213B), Color(0xFF0B213B)),
    'evening':   _Quad(Color(0xFF58A6FF), Color(0xFF8B949E), Color(0xFFECF2F8), Color(0xFFC9D1D9)),
    'night':     _Quad(Color(0xFF58A6FF), Color(0xFF8B949E), Color(0xFFF0F6FC), Color(0xFFC9D1D9)),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers — used by the screens, no need to touch these
  // ─────────────────────────────────────────────────────────────────────────

  static const _map = {
    'catppuccin-latte': _catppuccinLatte,
    'rose-pine-dawn':   _rosePineDawn,
    'mint-light':       _mintLight,
    'one-light':        _oneLight,
    'orchid':           _orchid,
    'gruvbox':          _gruvbox,
    'everforest':       _everforest,
    'github-dark':      _githubDark,
  };

  static String getTimeSlot() {
    final time = DateTime.now().hour + DateTime.now().minute / 60.0;
    if (time >= 5.0 && time < 11.5) {
      return 'morning';
    } else if (time >= 11.5 && time < 16.0) {
      return 'afternoon';
    } else if (time >= 16.0 && time < 20.0) {
      return 'evening';
    } else {
      return 'night';
    }
  }

  /// Title color for text overlaid on the background image.
  static Color titleColor(String themeKey, [String? timeSlot]) {
    final slot = timeSlot ?? getTimeSlot();
    return _map[themeKey]?[slot]?.title ?? const Color(0xFFFFFFFF);
  }

  /// Subtitle/tagline color for text overlaid on the background image.
  static Color subtitleColor(String themeKey, [String? timeSlot]) {
    final slot = timeSlot ?? getTimeSlot();
    return _map[themeKey]?[slot]?.subtitle ?? const Color(0xCCFFFFFF);
  }

  /// Greeting color ("Good morning, Name"). Returns null → caller uses U.text.
  static Color? greetingColor(String themeKey, [String? timeSlot]) {
    final slot = timeSlot ?? getTimeSlot();
    return _map[themeKey]?[slot]?.greeting;
  }

  /// Quote/motivational text color. Returns null → caller uses U.sub.
  static Color? quoteColor(String themeKey, [String? timeSlot]) {
    final slot = timeSlot ?? getTimeSlot();
    return _map[themeKey]?[slot]?.quote;
  }
}

/// Holds four colors: title, subtitle, greeting, quote.
/// greeting/quote can be null → screen falls back to U.text/U.sub.
class _Quad {
  final Color title;
  final Color subtitle;
  final Color? greeting;
  final Color? quote;
  const _Quad(this.title, this.subtitle, this.greeting, this.quote);
}
