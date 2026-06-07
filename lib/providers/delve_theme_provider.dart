import 'package:flutter/material.dart';
import '../theme/delve_theme.dart';
import '../main.dart';

class DelveThemeProvider extends ChangeNotifier {
  DelveTheme get currentTheme => DelveTheme(
        name: 'Utopia',
        background: U.bg,
        text: U.text,
        botanicalInk: U.border.withValues(alpha: 0.15),
        accent: U.teal,
        accentSecondary: U.primary,
        isDark: appThemeNotifier.value.isDark,
        feel: 'Native Utopia visual styling.',
        flowerType: FlowerType.wisteria,
      );

  bool get shouldSyncToFirestore => false;

  void toggleMode() {}
  void setTheme(dynamic theme) {}
}
