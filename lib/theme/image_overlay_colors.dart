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
    'morning':   _Quad(Color(0xFF211047), Color(0xFF141438), Color(0xFF110826), Color(0xFF1F0F42)), // ← change me
    'afternoon': _Quad(Color(0xFF211047), Color(0xFF141438), Color(0xFF110826), Color(0xFF1F0F42)), // ← change me
    'evening':   _Quad(Color(0xFFBAA3FF), Color(0xFFC7C7C7), Color(0xFFE8E8E8), Color(0xFFC7C7C7)), // ← change me
    'night':     _Quad(Color(0xFF834ACF), Color(0xFF9093B0), Color(0xFFDCE0E8), Color(0xFFBCC0CC)), // ← change me
  };

  // ── Rosé Pine Dawn ── (light theme)
  static const _rosePineDawn = {
    'morning':   _Quad(Color(0xFF360A08), Color(0xFF381514), Color(0xFF1F0403), Color(0xFF330705)), // ← change me
    'afternoon': _Quad(Color(0xFF360A08), Color(0xFF381514), Color(0xFF1F0403), Color(0xFF330705)), // ← change me
    'evening':   _Quad(Color(0xFFD7827E), Color(0xFFC9C9C9), Color(0xFFEDEDED), Color(0xFFC9C9C9)), // ← change me
    'night':     _Quad(Color(0xFFD7827E), Color(0xFF797593), Color(0xFFFAF4ED), Color(0xFFDFDAD9)), // ← change me
  };

  // ── Mint Light ── (light theme)
  static const _mintLight = {
    'morning':   _Quad(Color(0xFF072B1F), Color(0xFF0C2B22), Color(0xFF021A12), Color(0xFF043022)), // ← change me
    'afternoon': _Quad(Color(0xFF072B1F), Color(0xFF0C2B22), Color(0xFF021A12), Color(0xFF043022)), // ← change me
    'evening':   _Quad(Color(0xFF00BF82), Color(0xFF258569), Color(0xFFF5F5F5), Color(0xFFC2C2C2)),// ← change me
    'night':     _Quad(Color(0xFF1E8F6A), Color(0xFF567C65), Color(0xFFF2FBF7), Color(0xFFBCE3CE)), // ← change me
  };

  // ── One Light ── (light theme)
  static const _oneLight = {
    'morning':   _Quad(Color(0xFF0D2554), Color(0xFF2A2B33), Color(0xFF0A0C14), Color(0xFF2A2B33)), // ← change me
    'afternoon': _Quad(Color(0xFF0D2554), Color(0xFF1F1F1F), Color(0xFF0A0C14), Color(0xFF1F1F1F)), // ← change me
    'evening':   _Quad(Color(0xFF4078F2), Color(0xFF98A9FA), Color(0xFFFCFDFF), Color(0xFFF5F7FF)), // ← change me
    'night':     _Quad(Color(0xFF4078F2), Color(0xFF696C77), Color(0xFFFAFAFA), Color(0xFFE5E5E6)), // ← change me
  };

  // ── Orchid ── (dark theme)  — null greeting/quote → falls back to U.text/U.sub
  static const _orchid = {
    'morning':   _Quad(Color(0xFF2D1A47), Color(0xFF230947), Color(0xFF220345), Color(0xFF220345)),
    'afternoon': _Quad(Color(0xFF2D1A47), Color(0xFF230947), Color(0xFF220345), Color(0xFF220345)),
    'evening':   _Quad(Color(0xFFCBA6F7), Color(0xFF8888A8), null, null),
    'night':     _Quad(Color(0xFFCBA6F7), Color(0xFF8888A8), null, null),
  };

  // ── Gruvbox ── (dark theme)
  static const _gruvbox = {
    'morning':   _Quad(Color(0xFF260900), Color(0xFF292821), Color(0xFF211600), Color(0xFFF292821)),
    'afternoon': _Quad(Color(0xFF260900), Color(0xFF292821), Color(0xFF211600), Color(0xFFF292821)),
    'evening':   _Quad(Color(0xFFFB4934), Color(0xFFC4B59C), Color(0xFFDBCFBF), Color(0xFFC4B59C)),
    'night':     _Quad(Color(0xFFFB4934), Color(0xFFC4B59C), Color(0xFFC4B59C), Color(0xFFC4B59C)),
  };

  // ── Everforest ── (dark theme)
  static const _everforest = {
    'morning':   _Quad(Color(0xFF1D3000), Color(0xFF131C04),  Color(0xFF111C00),  Color(0xFF111C00)),
    'afternoon':_Quad(Color(0xFF1D3000), Color(0xFF131C04),  Color(0xFF111C00),  Color(0xFF111C00)),
    'evening':   _Quad(Color(0xFFA7C080), Color(0xFFB0B0B0), null, null),
    'night':     _Quad(Color(0xFFA7C080), Color(0xFFB0B0B0), null, null),
  };

  // ── GitHub Dark ── (dark theme)
  static const _githubDark = {
    'morning':   _Quad(Color(0xFF0B213B), Color(0xFF132A45), Color(0xFF0B213B), Color(0xFF0B213B)),
    'afternoon': _Quad(Color(0xFF0B213B), Color(0xFF132A45), Color(0xFF0B213B), Color(0xFF0B213B)),
    'evening':   _Quad(Color(0xFF1782E6), Color(0xFF8B949E), null, null),
    'night':     _Quad(Color(0xFF58A6FF), Color(0xFF8B949E), null, null),
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
    } else if (time >= 16.0 && time < 18.5) {
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
