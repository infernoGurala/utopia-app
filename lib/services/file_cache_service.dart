import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class FileCacheService {
  static final FileCacheService _instance = FileCacheService._internal();

  factory FileCacheService() => _instance;

  FileCacheService._internal();

  final Dio _dio = Dio();

  String _cacheKey(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }

  String _driveDirectUrl(String url) {
    final regExp = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(url);
    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    return url;
  }

  Future<String> _cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/utopia_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<bool> isCached(String url) async {
    final dir = await _cacheDir();
    final file = File('$dir/${_cacheKey(url)}');
    return file.exists();
  }

  Future<String?> getCachedPath(String url) async {
    final dir = await _cacheDir();
    final file = File('$dir/${_cacheKey(url)}');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<String> pathForUrl(String url) async {
    final dir = await _cacheDir();
    return '$dir/${_cacheKey(url)}';
  }

  Future<void> deleteCached(String url) async {
    final dir = await _cacheDir();
    final file = File('$dir/${_cacheKey(url)}');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> getCachedImagePath(String url) async {
    final path = await getCachedPath(url);
    if (path == null) {
      return null;
    }

    final file = File(path);
    final bytes = await file.readAsBytes();
    if (_looksLikeImageBytes(bytes)) {
      return path;
    }

    await file.delete();
    return null;
  }

  Future<String?> downloadFile(
    String url, {
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await _cacheDir();
      final key = _cacheKey(url);
      final filePath = '$dir/$key';
      final directUrl = _driveDirectUrl(url);

      await _dio.download(
        directUrl,
        filePath,
        deleteOnError: true,
        onReceiveProgress: onProgress,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Returns the local file path for [url], downloading it first if needed.
  Future<String?> getOrDownload(String url) async {
    final cached = await getCachedPath(url);
    if (cached != null) return cached;
    return downloadFile(url);
  }

  Future<String?> saveBytes(String url, List<int> bytes) async {
    try {
      final filePath = await pathForUrl(url);
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  bool _looksLikeImageBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return false;
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }

    if (bytes.length >= 6) {
      final gifHeader = ascii.decode(bytes.take(6).toList(), allowInvalid: true);
      if (gifHeader == 'GIF87a' || gifHeader == 'GIF89a') {
        return true;
      }
    }

    if (bytes.length >= 12) {
      final riff = ascii.decode(bytes.take(4).toList(), allowInvalid: true);
      final webp = ascii.decode(
        bytes.sublist(8, 12),
        allowInvalid: true,
      );
      if (riff == 'RIFF' && webp == 'WEBP') {
        return true;
      }
    }

    if (bytes.length >= 2 &&
        bytes[0] == 0x42 &&
        bytes[1] == 0x4D) {
      return true;
    }

    final probeLength = bytes.length > 512 ? 512 : bytes.length;
    final probe = utf8.decode(
      bytes.take(probeLength).toList(),
      allowMalformed: true,
    ).toLowerCase();
    if (probe.contains('<svg')) {
      return true;
    }

    return false;
  }
}
