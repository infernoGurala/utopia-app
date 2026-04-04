import 'package:flutter/foundation.dart';

class PlatformSupport {
  PlatformSupport._();

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get supportsFirebase {
    return isAndroid || isIOS;
  }

  static bool get supportsGoogleSignIn => isAndroid || isIOS;

  static bool get supportsNotifications =>
      isAndroid || isIOS || defaultTargetPlatform == TargetPlatform.macOS;

  static bool get supportsCampusMap => isAndroid || isIOS;

  static bool get supportsEmbeddedWebView =>
      isAndroid || isIOS || defaultTargetPlatform == TargetPlatform.macOS;
}
