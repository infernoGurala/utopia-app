import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.apkUrl,
    required this.title,
    required this.message,
    required this.force,
  });

  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final String apkUrl;
  final String title;
  final String message;
  final bool force;

  bool get shouldUpdate =>
      AppUpdateService.compareVersions(latestVersion, currentVersion) > 0;

  bool get requiresImmediateUpdate =>
      force ||
      AppUpdateService.compareVersions(minimumVersion, currentVersion) > 0;
}

class AppUpdateService {
  AppUpdateService._();

  static final Dio _dio = Dio();
  static const MethodChannel _channel = MethodChannel('utopia_app/app_update');

  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app_update')
          .get();
      final data = doc.data();
      if (data == null) {
        return null;
      }

      final latestVersion =
          (data['androidLatestVersion'] ?? data['latestVersion'] ?? '')
              .toString()
              .trim();
      final minimumVersion =
          (data['androidMinimumVersion'] ?? data['minimumVersion'] ?? '0.0.0')
              .toString()
              .trim();
      final apkUrl = (data['androidApkUrl'] ?? data['apkUrl'] ?? '')
          .toString()
          .trim();

      if (latestVersion.isEmpty || apkUrl.isEmpty) {
        return null;
      }

      final title = (data['title'] ?? 'Update Available').toString().trim();
      final message =
          (data['message'] ??
                  'A newer version of UTOPIA is available. Download and install it now.')
              .toString()
              .trim();
      final force = data['force'] == true;

      final info = AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minimumVersion: minimumVersion,
        apkUrl: apkUrl,
        title: title.isEmpty ? 'Update Available' : title,
        message: message.isEmpty
            ? 'A newer version of UTOPIA is available.'
            : message,
        force: force,
      );

      return info.shouldUpdate ? info : null;
    } catch (_) {
      return null;
    }
  }

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var i = 0; i < maxLength; i++) {
      final l = i < leftParts.length ? leftParts[i] : 0;
      final r = i < rightParts.length ? rightParts[i] : 0;
      if (l != r) {
        return l.compareTo(r);
      }
    }
    return 0;
  }

  static List<int> _versionParts(String input) {
    return input
        .split('.')
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList();
  }

  static Future<String> downloadApk(
    String apkUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/utopia-update.apk';
    await _dio.download(
      apkUrl,
      filePath,
      deleteOnError: true,
      onReceiveProgress: onProgress,
      options: Options(
        followRedirects: true,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    return filePath;
  }

  static Future<bool> canInstallDownloadedApk() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final result = await _channel.invokeMethod<bool>('canInstallApk');
    return result ?? false;
  }

  static Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  static Future<String> installDownloadedApk(String filePath) async {
    if (!Platform.isAndroid) {
      return 'unsupported_platform';
    }

    final result = await _channel.invokeMethod<String>('installApk', {
      'filePath': filePath,
    });
    return result ?? 'failed';
  }
}
