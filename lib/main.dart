import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'services/app_update_service.dart';
import 'services/cache_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/platform_support.dart';
import 'screens/app_shell.dart';
import 'screens/join_class_screen.dart';
import 'screens/university_selection_screen.dart';
import 'services/class_service.dart';
import 'widgets/app_update_prompt.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final Future<AppInitializationState> appInitialization;

class AppInitializationState {
  const AppInitializationState({
    required this.firebaseReady,
    this.blockingMessage,
  });

  final bool firebaseReady;
  final String? blockingMessage;
}

class AppTheme {
  const AppTheme({
    required this.key,
    required this.label,
    required this.description,
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.text,
    required this.sub,
    required this.dim,
    required this.primary,
    required this.teal,
    required this.red,
    required this.green,
    required this.peach,
    required this.blue,
    required this.gold,
    required this.sky,
    required this.lavender,
    required this.gray,
    required this.mdH1,
    required this.mdH2,
    required this.mdH3,
    required this.mdBold,
    required this.mdItalic,
    required this.mdCode,
    required this.mdLink,
    required this.mdBlockquote,
    required this.mdDel,
    required this.mermaidPrimary,
    required this.mermaidBackground,
    required this.mermaidLine,
  });

  final String key;
  final String label;
  final String description;
  final bool isDark;
  final Color bg;
  final Color surface;
  final Color card;
  final Color border;
  final Color text;
  final Color sub;
  final Color dim;
  final Color primary;
  final Color teal;
  final Color red;
  final Color green;
  final Color peach;
  final Color blue;
  final Color gold;
  final Color sky;
  final Color lavender;
  final Color gray;
  final Color mdH1;
  final Color mdH2;
  final Color mdH3;
  final Color mdBold;
  final Color mdItalic;
  final Color mdCode;
  final Color mdLink;
  final Color mdBlockquote;
  final Color mdDel;
  final String mermaidPrimary;
  final String mermaidBackground;
  final String mermaidLine;
}

const _orchidTheme = AppTheme(
  key: 'orchid',
  label: 'Orchid',
  description: 'Soft purple with warm undertones',
  isDark: true,
  bg: Color(0xFF0F0F17),
  surface: Color(0xFF1A1A27),
  card: Color(0xFF1F1F2E),
  border: Color(0xFF2A2A3D),
  text: Color(0xFFE8E8F0),
  sub: Color(0xFF8888A8),
  dim: Color(0xFF44445A),
  primary: Color(0xFFCBA6F7),
  teal: Color(0xFF94E2D5),
  red: Color(0xFFF38BA8),
  green: Color(0xFFA6E3A1),
  peach: Color(0xFFFAB387),
  blue: Color(0xFF89B4FA),
  gold: Color(0xFFF9E2AF),
  sky: Color(0xFF89DCEB),
  lavender: Color(0xFFB4BEFE),
  gray: Color(0xFFA6ADC8),
  mdH1: Color(0xFFCBA6F7),
  mdH2: Color(0xFF94E2D5),
  mdH3: Color(0xFFB4BEFE),
  mdBold: Color(0xFFFAB387),
  mdItalic: Color(0xFFA6E3A1),
  mdCode: Color(0xFFF38BA8),
  mdLink: Color(0xFF89B4FA),
  mdBlockquote: Color(0xFFCBA6F7),
  mdDel: Color(0xFF44445A),
  mermaidPrimary: '#CBA6F7',
  mermaidBackground: '#1F1F2E',
  mermaidLine: '#CBA6F7',
);

const _tokyonightTheme = AppTheme(
  key: 'tokyonight',
  label: 'Tokyo Night',
  description: 'Elegant dark theme with blue undertones',
  isDark: true,
  bg: Color(0xFF1A1B26),
  surface: Color(0xFF24283B),
  card: Color(0xFF292E42),
  border: Color(0xFF414868),
  text: Color(0xFFC0CAF5),
  sub: Color(0xFF8B8FB3),
  dim: Color(0xFF3B4261),
  primary: Color(0xFF7AA2F7),
  teal: Color(0xFF7DCFFF),
  red: Color(0xFFF7768E),
  green: Color(0xFF9ECE6A),
  peach: Color(0xFFFF9E64),
  blue: Color(0xFF7AA2F7),
  gold: Color(0xFFFFD57E),
  sky: Color(0xFF7DCFFF),
  lavender: Color(0xFFBB9AF7),
  gray: Color(0xFF565F89),
  mdH1: Color(0xFF7AA2F7),
  mdH2: Color(0xFF7DCFFF),
  mdH3: Color(0xFFBB9AF7),
  mdBold: Color(0xFFFF9E64),
  mdItalic: Color(0xFF9ECE6A),
  mdCode: Color(0xFFF7768E),
  mdLink: Color(0xFF7AA2F7),
  mdBlockquote: Color(0xFF7AA2F7),
  mdDel: Color(0xFF3B4261),
  mermaidPrimary: '#7AA2F7',
  mermaidBackground: '#292E42',
  mermaidLine: '#7AA2F7',
);

const _catppuccinMochaTheme = AppTheme(
  key: 'catppuccin-mocha',
  label: 'Catppuccin Mocha',
  description: 'Lavender meets chocolate',
  isDark: true,
  bg: Color(0xFF1E1E2E),
  surface: Color(0xFF313244),
  card: Color(0xFF45475A),
  border: Color(0xFF585B70),
  text: Color(0xFFCDD6F4),
  sub: Color(0xFFA6ADC8),
  dim: Color(0xFF6C7086),
  primary: Color(0xFFCBA6F7),
  teal: Color(0xFF94E2D5),
  red: Color(0xFFF38BA8),
  green: Color(0xFFA6E3A1),
  peach: Color(0xFFFAB387),
  blue: Color(0xFF89B4FA),
  gold: Color(0xFFF9E2AF),
  sky: Color(0xFF89DCEB),
  lavender: Color(0xFFB4BEFE),
  gray: Color(0xFF8B92A4),
  mdH1: Color(0xFFCBA6F7),
  mdH2: Color(0xFF94E2D5),
  mdH3: Color(0xFFB4BEFE),
  mdBold: Color(0xFFFAB387),
  mdItalic: Color(0xFFA6E3A1),
  mdCode: Color(0xFFF38BA8),
  mdLink: Color(0xFF89B4FA),
  mdBlockquote: Color(0xFFCBA6F7),
  mdDel: Color(0xFF6C7086),
  mermaidPrimary: '#CBA6F7',
  mermaidBackground: '#45475A',
  mermaidLine: '#CBA6F7',
);

const _gruvboxTheme = AppTheme(
  key: 'gruvbox',
  label: 'Gruvbox',
  description: 'Retro warmth with dark background',
  isDark: true,
  bg: Color(0xFF282828),
  surface: Color(0xFF32302F),
  card: Color(0xFF3C3836),
  border: Color(0xFF504945),
  text: Color(0xFFEBDBB2),
  sub: Color(0xFFC4B59C),
  dim: Color(0xFF665C54),
  primary: Color(0xFFFB4934),
  teal: Color(0xFF8EC07C),
  red: Color(0xFFFB4934),
  green: Color(0xFFB8BB26),
  peach: Color(0xFFE6B450),
  blue: Color(0xFF83A598),
  gold: Color(0xFFFAB387),
  sky: Color(0xFF8EC07C),
  lavender: Color(0xFF83A598),
  gray: Color(0xFFA89984),
  mdH1: Color(0xFFFB4934),
  mdH2: Color(0xFF8EC07C),
  mdH3: Color(0xFF83A598),
  mdBold: Color(0xFFE6B450),
  mdItalic: Color(0xFFB8BB26),
  mdCode: Color(0xFFFB4934),
  mdLink: Color(0xFF83A598),
  mdBlockquote: Color(0xFFFB4934),
  mdDel: Color(0xFF665C54),
  mermaidPrimary: '#FB4934',
  mermaidBackground: '#3C3836',
  mermaidLine: '#FB4934',
);

const _everforestTheme = AppTheme(
  key: 'everforest',
  label: 'Everforest',
  description: 'Low contrast forest theme',
  isDark: true,
  bg: Color(0xFF272E33),
  surface: Color(0xFF333C43),
  card: Color(0xFF3E474C),
  border: Color(0xFF4E5660),
  text: Color(0xFFD5C4A1),
  sub: Color(0xFFB0B0B0),
  dim: Color(0xFF5A6268),
  primary: Color(0xFFA7C080),
  teal: Color(0xFF7FAAA7),
  red: Color(0xFFE67F5C),
  green: Color(0xFFA7C080),
  peach: Color(0xFFFAB387),
  blue: Color(0xFF7FAAA7),
  gold: Color(0xFFE6B450),
  sky: Color(0xFF7FAAA7),
  lavender: Color(0xFF8DA101),
  gray: Color(0xFFB0B0B0),
  mdH1: Color(0xFFA7C080),
  mdH2: Color(0xFF7FAAA7),
  mdH3: Color(0xFF7FAAA7),
  mdBold: Color(0xFFFAB387),
  mdItalic: Color(0xFFA7C080),
  mdCode: Color(0xFFE67F5C),
  mdLink: Color(0xFF7FAAA7),
  mdBlockquote: Color(0xFFA7C080),
  mdDel: Color(0xFF5A6268),
  mermaidPrimary: '#A7C080',
  mermaidBackground: '#3E474C',
  mermaidLine: '#A7C080',
);

const _ayuTheme = AppTheme(
  key: 'ayu',
  label: 'Ayu',
  description: 'Fast, clean and modern',
  isDark: true,
  bg: Color(0xFF0D1117),
  surface: Color(0xFF161B22),
  card: Color(0xFF21262D),
  border: Color(0xFF30363D),
  text: Color(0xFFB3B1AD),
  sub: Color(0xFF8A9199),
  dim: Color(0xFF525A66),
  primary: Color(0xFF39BAE6),
  teal: Color(0xFF5FD4A4),
  red: Color(0xFFF07178),
  green: Color(0xFF87D96C),
  peach: Color(0xFFFFB454),
  blue: Color(0xFF39BAE6),
  gold: Color(0xFFFFB454),
  sky: Color(0xFF5FD4A4),
  lavender: Color(0xFFC77DBA),
  gray: Color(0xFF8A9199),
  mdH1: Color(0xFF39BAE6),
  mdH2: Color(0xFF5FD4A4),
  mdH3: Color(0xFF7AA2F7),
  mdBold: Color(0xFFFFB454),
  mdItalic: Color(0xFF87D96C),
  mdCode: Color(0xFFF07178),
  mdLink: Color(0xFF39BAE6),
  mdBlockquote: Color(0xFF39BAE6),
  mdDel: Color(0xFF525A66),
  mermaidPrimary: '#39BAE6',
  mermaidBackground: '#21262D',
  mermaidLine: '#39BAE6',
);

const _poimandresAccessibleTheme = AppTheme(
  key: 'poimandres-accessible',
  label: 'Poimandres Accessible',
  description: 'High contrast variant',
  isDark: true,
  bg: Color(0xFF0D1117),
  surface: Color(0xFF161B22),
  card: Color(0xFF21262D),
  border: Color(0xFF30363D),
  text: Color(0xFFC9D1D9),
  sub: Color(0xFF8B949E),
  dim: Color(0xFF484F58),
  primary: Color(0xFF79C0FF),
  teal: Color(0xFF56D4DD),
  red: Color(0xFFFF7B72),
  green: Color(0xFF7EE787),
  peach: Color(0xFFFFA657),
  blue: Color(0xFF79C0FF),
  gold: Color(0xFFFFA657),
  sky: Color(0xFF56D4DD),
  lavender: Color(0xFFA371F7),
  gray: Color(0xFF8B949E),
  mdH1: Color(0xFF79C0FF),
  mdH2: Color(0xFF56D4DD),
  mdH3: Color(0xFFA371F7),
  mdBold: Color(0xFFFFA657),
  mdItalic: Color(0xFF7EE787),
  mdCode: Color(0xFFFF7B72),
  mdLink: Color(0xFF79C0FF),
  mdBlockquote: Color(0xFF79C0FF),
  mdDel: Color(0xFF484F58),
  mermaidPrimary: '#79C0FF',
  mermaidBackground: '#21262D',
  mermaidLine: '#79C0FF',
);

const _githubDarkTheme = AppTheme(
  key: 'github-dark',
  label: 'GitHub Dark',
  description: 'GitHub dark mode inspired',
  isDark: true,
  bg: Color(0xFF0D1117),
  surface: Color(0xFF161B22),
  card: Color(0xFF21262D),
  border: Color(0xFF30363D),
  text: Color(0xFFC9D1D9),
  sub: Color(0xFF8B949E),
  dim: Color(0xFF484F58),
  primary: Color(0xFF58A6FF),
  teal: Color(0xFF3FB950),
  red: Color(0xFFF85149),
  green: Color(0xFF56D364),
  peach: Color(0xFFD29922),
  blue: Color(0xFF58A6FF),
  gold: Color(0xFFD29922),
  sky: Color(0xFF56D364),
  lavender: Color(0xFFA371F7),
  gray: Color(0xFF8B949E),
  mdH1: Color(0xFF58A6FF),
  mdH2: Color(0xFF3FB950),
  mdH3: Color(0xFFA371F7),
  mdBold: Color(0xFFD29922),
  mdItalic: Color(0xFF3FB950),
  mdCode: Color(0xFFF85149),
  mdLink: Color(0xFF58A6FF),
  mdBlockquote: Color(0xFF58A6FF),
  mdDel: Color(0xFF484F58),
  mermaidPrimary: '#58A6FF',
  mermaidBackground: '#21262D',
  mermaidLine: '#58A6FF',
);

const _catppuccinLatteTheme = AppTheme(
  key: 'catppuccin-latte',
  label: 'Catppuccin Latte',
  description: 'Soft daylight with balanced contrast',
  isDark: false,
  bg: Color(0xFFEFF1F5),
  surface: Color(0xFFDCE0E8),
  card: Color(0xFFCCD0DA),
  border: Color(0xFFBCC0CC),
  text: Color(0xFF4C4F69),
  sub: Color(0xFF6C6F85),
  dim: Color(0xFF8C8FA1),
  primary: Color(0xFF8839EF),
  teal: Color(0xFF179299),
  red: Color(0xFFD20F39),
  green: Color(0xFF40A02B),
  peach: Color(0xFFFE640B),
  blue: Color(0xFF1E66F5),
  gold: Color(0xFFDF8E1D),
  sky: Color(0xFF04A5E5),
  lavender: Color(0xFF7287FD),
  gray: Color(0xFF9CA0B0),
  mdH1: Color(0xFF8839EF),
  mdH2: Color(0xFF179299),
  mdH3: Color(0xFF7287FD),
  mdBold: Color(0xFFFE640B),
  mdItalic: Color(0xFF40A02B),
  mdCode: Color(0xFFD20F39),
  mdLink: Color(0xFF1E66F5),
  mdBlockquote: Color(0xFF8839EF),
  mdDel: Color(0xFF8C8FA1),
  mermaidPrimary: '#8839EF',
  mermaidBackground: '#CCD0DA',
  mermaidLine: '#8839EF',
);

const appThemes = [
  _catppuccinLatteTheme,
  _orchidTheme,
  _tokyonightTheme,
  _catppuccinMochaTheme,
  _gruvboxTheme,
  _everforestTheme,
  _ayuTheme,
  _poimandresAccessibleTheme,
  _githubDarkTheme,
];

final ValueNotifier<AppTheme> appThemeNotifier = ValueNotifier<AppTheme>(
  _orchidTheme,
);

final ValueNotifier<bool> iaaEnabledNotifier = ValueNotifier<bool>(false);
final ValueNotifier<bool> morningNotifEnabledNotifier = ValueNotifier<bool>(true);
final ValueNotifier<bool> sciWordleNotifEnabledNotifier = ValueNotifier<bool>(true);

final ValueNotifier<int> appLoadingCounter = ValueNotifier<int>(0);

void _applySystemUiForTheme(AppTheme theme) {
  final usesLightIcons = theme.isDark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          usesLightIcons ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          usesLightIcons ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.bg,
      systemNavigationBarIconBrightness:
          usesLightIcons ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: theme.border,
    ),
  );
}

void showAppLoading() {
  appLoadingCounter.value = appLoadingCounter.value + 1;
}

void hideAppLoading() {
  if (appLoadingCounter.value > 0) {
    appLoadingCounter.value = appLoadingCounter.value - 1;
  }
}

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appLoadingCounter,
      builder: (context, count, _) {
        return Stack(
          children: [
            child,
            if (count > 0)
              Positioned.fill(
                child: Container(
                  color: U.bg.withValues(alpha: 0.85),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: U.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: U.border),
                        boxShadow: [
                          BoxShadow(
                            color: U.primary.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: U.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: GoogleFonts.outfit(
                              color: U.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AppAccentStyle {
  const AppAccentStyle({
    required this.key,
    required this.label,
    required this.primary,
  });

  final String key;
  final String label;
  final Color primary;
}

Future<AppInitializationState> _initializeApp() async {
  if (PlatformSupport.isWindows) {
    return const AppInitializationState(
      firebaseReady: false,
      blockingMessage:
          'Windows support is only partially configured. Add a Windows Firebase app and a desktop authentication flow before signing in on Windows.',
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (PlatformSupport.supportsNotifications) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      unawaited(NotificationService.initialize());
    }
    return const AppInitializationState(firebaseReady: true);
  } catch (e) {
    return AppInitializationState(
      firebaseReady: false,
      blockingMessage:
          'Firebase failed to initialize on this platform. Check the desktop Firebase configuration before building for Windows.',
    );
  }
}

String? _initialAccentKey;

Future<String?> _loadInitialAccent() async {
  final cached = await CacheService().getAppSetting('theme_accent');
  return cached;
}

Future<void> _loadAppToggleSettings() async {
  final cachedIaa = await CacheService().getAppSetting('iaa_enabled');
  if (cachedIaa != null) {
    iaaEnabledNotifier.value = cachedIaa == 'true';
  }
  final cachedMorning = await CacheService().getAppSetting('morning_notif_enabled');
  if (cachedMorning != null) {
    morningNotifEnabledNotifier.value = cachedMorning == 'true';
  }
  final cachedWordle = await CacheService().getAppSetting('sci_wordle_notif_enabled');
  if (cachedWordle != null) {
    sciWordleNotifEnabledNotifier.value = cachedWordle == 'true';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initialAccentKey = await _loadInitialAccent();
  U.applyTheme(_initialAccentKey);
  await _loadAppToggleSettings();
  appInitialization = _initializeApp();
  _applySystemUiForTheme(appThemeNotifier.value);
  runApp(const UtopiaApp());
}

class U {
  static Color get bg => appThemeNotifier.value.bg;
  static Color get surface => appThemeNotifier.value.surface;
  static Color get card => appThemeNotifier.value.card;
  static Color get border => appThemeNotifier.value.border;
  static Color get primary => appThemeNotifier.value.primary;
  static Color get teal => appThemeNotifier.value.teal;
  static Color get text => appThemeNotifier.value.text;
  static Color get sub => appThemeNotifier.value.sub;
  static Color get dim => appThemeNotifier.value.dim;
  static Color get red => appThemeNotifier.value.red;
  static Color get green => appThemeNotifier.value.green;
  static Color get peach => appThemeNotifier.value.peach;
  static Color get blue => appThemeNotifier.value.blue;
  static Color get gold => appThemeNotifier.value.gold;
  static Color get sky => appThemeNotifier.value.sky;
  static Color get lavender => appThemeNotifier.value.lavender;
  static Color get gray => appThemeNotifier.value.gray;

  static Color get mdH1 => appThemeNotifier.value.mdH1;
  static Color get mdH2 => appThemeNotifier.value.mdH2;
  static Color get mdH3 => appThemeNotifier.value.mdH3;
  static Color get mdBold => appThemeNotifier.value.mdBold;
  static Color get mdItalic => appThemeNotifier.value.mdItalic;
  static Color get mdCode => appThemeNotifier.value.mdCode;
  static Color get mdLink => appThemeNotifier.value.mdLink;
  static Color get mdBlockquote => appThemeNotifier.value.mdBlockquote;
  static Color get mdDel => appThemeNotifier.value.mdDel;

  static String get mermaidPrimary => appThemeNotifier.value.mermaidPrimary;
  static String get mermaidBackground =>
      appThemeNotifier.value.mermaidBackground;
  static String get mermaidLine => appThemeNotifier.value.mermaidLine;

  static String get currentThemeKey => appThemeNotifier.value.key;

  static bool get iaaEnabled => iaaEnabledNotifier.value;
  static bool get morningNotifEnabled => morningNotifEnabledNotifier.value;
  static bool get sciWordleNotifEnabled => sciWordleNotifEnabledNotifier.value;

  static AppTheme themeForKey(String? key) {
    for (final theme in appThemes) {
      if (theme.key == key) {
        return theme;
      }
    }
    return _orchidTheme;
  }

  static void applyTheme(String? key) {
    final next = themeForKey(key);
    if (appThemeNotifier.value.key == next.key) {
      return;
    }
    appThemeNotifier.value = next;
    _applySystemUiForTheme(next);
  }
}

class UtopiaApp extends StatelessWidget {
  const UtopiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.outfitTextTheme();
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, theme, _) {
        final isDark = theme.isDark;
        return MaterialApp(
          title: 'UTOPIA',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData(
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            textTheme: base.apply(bodyColor: U.text, displayColor: U.text),
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: U.primary,
                    onPrimary: U.bg,
                    secondary: U.teal,
                    onSecondary: U.bg,
                    surface: U.surface,
                    onSurface: U.text,
                    background: U.bg,
                    onBackground: U.text,
                    error: U.red,
                    outline: U.border,
                )
                : ColorScheme.light(
                    primary: U.primary,
                    onPrimary: Colors.white,
                    secondary: U.teal,
                    onSecondary: Colors.white,
                    surface: U.surface,
                    onSurface: U.text,
                    background: U.bg,
                    onBackground: U.text,
                    error: U.red,
                    outline: U.border,
                ),
            scaffoldBackgroundColor: U.bg,
            cardTheme: CardThemeData(
              color: U.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              margin: EdgeInsets.zero,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                elevation: 0,
                foregroundColor: U.text,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: U.primary.withValues(alpha: 0.5)),
              ),
              hintStyle: GoogleFonts.outfit(
                color: U.sub.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              labelStyle: GoogleFonts.outfit(
                color: U.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            dividerTheme: DividerThemeData(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              thickness: 1,
              space: 1,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: U.surface,
              indicatorColor: U.primary.withValues(alpha: 0.15),
              labelTextStyle: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return GoogleFonts.outfit(
                    color: U.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  );
                }
                return GoogleFonts.outfit(
                  color: U.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                );
              }),
              iconTheme: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return IconThemeData(color: U.primary, size: 22);
                }
                return IconThemeData(color: U.dim, size: 22);
              }),
              elevation: 0,
              height: 64,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: U.bg,
              elevation: 0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
              ),
              titleTextStyle: GoogleFonts.outfit(
                color: U.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              iconTheme: IconThemeData(color: U.sub),
            ),
            dividerColor: U.border,
          ),
          home: const AppLoadingOverlay(child: AuthGate()),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final Future<AppInitializationState> _appInit = appInitialization;
  bool _greetingCyclePassed = false;
  bool _updateDismissed = false;
  AppUpdateInfo? _pendingUpdate;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.setAppForeground(true);
    if (PlatformSupport.supportsNotifications) {
      unawaited(NotificationService.ensureNotificationPermissions());
    }
    _loadUpdateInfo();
    _initDeepLinks();
    Future.delayed(SplashScreen.minimumDisplayDuration, () {
      if (mounted) {
        setState(() => _greetingCyclePassed = true);
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.setAppForeground(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationService.setAppForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      unawaited(ChatService().touchPresence());
      if (PlatformSupport.supportsNotifications) {
        unawaited(NotificationService.ensureNotificationPermissions());
        unawaited(NotificationService.refreshTokenRegistration());
        unawaited(NotificationService.maybeShowPendingDialog());
      }
    }
  }

  Future<void> _loadUpdateInfo() async {
    await _appInit;
    final updateInfo = await AppUpdateService.checkForUpdate();
    if (!mounted || updateInfo == null) {
      return;
    }
    setState(() {
      _pendingUpdate = updateInfo;
    });
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri);
    });
    _linkSub = appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    if (uri.path.startsWith('/join/')) {
      final classCode = uri.pathSegments.last;
      if (classCode.isEmpty) return;
      // Wait for navigator to be ready, then push the join screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => JoinClassScreen(classCode: classCode),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppInitializationState>(
      future: _appInit,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done ||
            !_greetingCyclePassed) {
          return const SplashScreen();
        }
        final initState =
            initSnapshot.data ??
            const AppInitializationState(firebaseReady: false);
        if (!initState.firebaseReady) {
          return _PlatformSetupScreen(
            message:
                initState.blockingMessage ??
                'This platform is not configured for UTOPIA yet.',
          );
        }
        if (_pendingUpdate != null &&
            !_updateDismissed &&
            _pendingUpdate!.shouldUpdate) {
          return AppUpdatePrompt(
            info: _pendingUpdate!,
            onSkip: () => setState(() => _updateDismissed = true),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            if (snapshot.hasData) {
              unawaited(ChatService().touchPresence());
              if (PlatformSupport.supportsNotifications) {
                unawaited(NotificationService.maybeShowPendingDialog());
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(snapshot.data!.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final themeAccent =
                      userSnapshot.data?.data()?['themeAccent'] as String?;
                  if (themeAccent != null) {
                    unawaited(
                      CacheService().saveAppSetting(
                        'theme_accent',
                        themeAccent,
                      ),
                    );
                  }

                  final selectedUniversityId = 
                      userSnapshot.data?.data()?['selectedUniversityId'] as String?;

                  if (userSnapshot.connectionState == ConnectionState.active && 
                      selectedUniversityId == null) {
                    return const UniversitySelectionScreen();
                  }

                  return const AppShell();
                },
              );
            }
            U.applyTheme(null);
            return const LoginScreen();
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const greetings = ['Hello', 'నమస్కారం', 'नमस्ते', 'こんにちは', '안녕하세요'];
  static const greetingStepDelay = Duration(milliseconds: 65);
  static const greetingAnimDuration = Duration(milliseconds: 45);
  static Duration get minimumDisplayDuration {
    final transitions = greetings.length - 1;
    final perTransition =
        greetingStepDelay.inMilliseconds +
        (greetingAnimDuration.inMilliseconds * 2);
    return Duration(milliseconds: transitions * perTransition);
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: SplashScreen.greetingAnimDuration,
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
    _slide = Tween<double>(
      begin: 6,
      end: 0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
    _cycle();
  }

  Future<void> _cycle() async {
    for (int i = 1; i < SplashScreen.greetings.length; i++) {
      await Future.delayed(SplashScreen.greetingStepDelay);
      if (!mounted) return;
      await _ac.reverse();
      setState(() => _idx = i);
      await _ac.forward();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _ac,
              builder: (context, _) => Opacity(
                opacity: _fade.value,
                child: Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: Text(
                    SplashScreen.greetings[_idx],
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: U.primary,
                      shadows: [
                        Shadow(
                          color: U.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'UTOPIA',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: U.sub,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    color: U.sub.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: _ac,
              builder: (context, _) {
                return Container(
                  width: 4 + (20 * _fade.value),
                  height: 4,
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.5 + (0.5 * _fade.value)),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: U.primary.withValues(alpha: 0.3 * _fade.value),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!PlatformSupport.supportsGoogleSignIn) {
      setState(() {
        _error =
            'Google sign-in is not available on Windows in this build. Add a desktop auth flow before shipping the Windows app.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '402670858978-94eqn0qvvrtv59ijne3hn1g5flr4ahve.apps.googleusercontent.com',
      );
      final user = await GoogleSignIn.instance.authenticate();
      final auth = user.authentication;
      final cred = GoogleAuthProvider.credential(idToken: auth.idToken);
      final credential = await FirebaseAuth.instance.signInWithCredential(cred);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user?.uid)
          .set({
            'displayName': credential.user?.displayName ?? '',
            'email': credential.user?.email ?? '',
            'photoUrl': credential.user?.photoURL,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      setState(() {
        _error = 'Sign-in failed. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 4),
                  Text(
                    'UTOPIA',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: U.primary,
                      fontStyle: FontStyle.italic,
                      height: 1,
                      letterSpacing: -1,
                      shadows: [
                        Shadow(
                          color: U.primary.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The Productivity Platform',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: U.sub,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: U.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: U.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.outfit(
                          color: U.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Animated container for the button state
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: U.primary.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading || !PlatformSupport.supportsGoogleSignIn
                          ? null
                          : _signIn,
                      child: _loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: U.bg,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _GoogleIcon(),
                                const SizedBox(width: 12),
                                Text(
                                  PlatformSupport.supportsGoogleSignIn
                                      ? 'Continue with Google'
                                      : 'Google sign-in unavailable',
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'UTOPIA · designed by Inferno',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: U.dim,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformSetupScreen extends StatelessWidget {
  const _PlatformSetupScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: U.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: U.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Windows Setup Needed',
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Current blockers: Firebase desktop config, desktop login, push notifications, and the campus map view.',
                      style: GoogleFonts.outfit(
                        color: U.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 18, height: 18, child: CustomPaint(painter: _GP()));
  }
}

class _GP extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final sw = size.width * 0.18;
    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw,
      );
    }

    arc(-1.2, 1.8, const Color(0xFF4285F4));
    arc(-2.8, 1.0, const Color(0xFFEA4335));
    arc(2.2, 0.8, const Color(0xFFFBBC05));
    arc(3.0, 0.5, const Color(0xFF34A853));
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r, cy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GP old) => false;
}
