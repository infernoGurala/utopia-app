import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// IMAGE OVERLAY COLORS
/// ─────────────────────────────────────────────────────────────────────────────
/// Colors for ALL text that sits on or near the background image:
///   • title    → "Utopia" / "University" / "Semesters"
///   • subtitle → tagline below title
///   • greeting → "Good morning, Name"  (sits in gradient transition zone)
///   • quote    → motivational text below greeting
/// ─────────────────────────────────────────────────────────────────────────────

class ImageOverlayColors {
  // ── Utopia Light ── (primary-light)
  static const _primaryLight = {
    'morning':   _Quad(Color(0xFF121212), Color(0xFF4C4C4C), Color(0xFF121212), Color(0xFF4C4C4C)),
    'afternoon': _Quad(Color(0xFF121212), Color(0xFF4C4C4C), Color(0xFF121212), Color(0xFF4C4C4C)),
    'evening':   _Quad(Color(0xFF121212), Color(0xFF4C4C4C), Color(0xFF121212), Color(0xFF4C4C4C)),
    'night':     _Quad(Color(0xFF121212), Color(0xFF4C4C4C), Color(0xFF121212), Color(0xFF4C4C4C)),
  };

  // ── Utopia Dark ── (primary-dark)
  static const _primaryDark = {
    'morning':   _Quad(Color(0xFFFBFBFA), Color(0xFFA6A6A6), Color(0xFFFBFBFA), Color(0xFFA6A6A6)),
    'afternoon': _Quad(Color(0xFFFBFBFA), Color(0xFFA6A6A6), Color(0xFFFBFBFA), Color(0xFFA6A6A6)),
    'evening':   _Quad(Color(0xFFFBFBFA), Color(0xFFA6A6A6), Color(0xFFFBFBFA), Color(0xFFA6A6A6)),
    'night':     _Quad(Color(0xFFFBFBFA), Color(0xFFA6A6A6), Color(0xFFFBFBFA), Color(0xFFA6A6A6)),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  static const _map = {
    'primary-light': _primaryLight,
    'primary-dark':  _primaryDark,
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

  /// Greeting color ("Good morning, Name").
  static Color? greetingColor(String themeKey, [String? timeSlot]) {
    final slot = timeSlot ?? getTimeSlot();
    return _map[themeKey]?[slot]?.greeting;
  }

  /// Quote/motivational text color.
  static Color? quoteColor(String themeKey, [String? timeSlot]) {
    final slot = timeSlot ?? getTimeSlot();
    return _map[themeKey]?[slot]?.quote;
  }
}

/// Holds four colors: title, subtitle, greeting, quote.
class _Quad {
  final Color title;
  final Color subtitle;
  final Color? greeting;
  final Color? quote;
  const _Quad(this.title, this.subtitle, this.greeting, this.quote);
}
