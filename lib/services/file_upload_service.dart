import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Maximum file size allowed for upload (20 MB).
const int kMaxUploadBytes = 20 * 1024 * 1024;

/// Hard limit — reject files above 30 MB outright.
const int kHardLimitBytes = 30 * 1024 * 1024;

/// Service for uploading files to Firebase Storage using a multi-bucket
/// architecture. Reads the active bucket from Firestore `app_config/storage_config`
/// and uploads to that bucket. When a bucket fills up (5 GB free tier), the admin
/// updates the Firestore config to point at a new bucket — no code changes needed.
class FileUploadService {
  static final FileUploadService _instance = FileUploadService._internal();
  factory FileUploadService() => _instance;
  FileUploadService._internal();

  String? _cachedBucketUrl;

  /// Fetch the active storage bucket URL from Firestore.
  Future<String?> _getActiveBucketUrl() async {
    if (_cachedBucketUrl != null) return _cachedBucketUrl;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('storage_config')
          .get();
      if (!doc.exists) return null;
      final url = doc.data()?['bucket_url'] as String?;
      if (url != null && url.isNotEmpty) {
        _cachedBucketUrl = url;
      }
      return url;
    } catch (e) {
      debugPrint('FileUploadService: Failed to fetch storage config: $e');
      return null;
    }
  }

  /// Let the user pick a file. Returns null if cancelled or file too large.
  /// Returns a tuple of (File, original filename).
  Future<(File, String)?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    if (picked.path == null) return null;
    
    final file = File(picked.path!);
    final size = await file.length();
    
    if (size > kHardLimitBytes) {
      throw FileUploadException(
        'File is too large (${(size / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Maximum allowed is 30 MB.',
      );
    }
    if (size > kMaxUploadBytes) {
      throw FileUploadException(
        'File exceeds recommended size of 20 MB '
        '(${(size / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Please use a smaller file.',
      );
    }
    
    return (file, picked.name);
  }

  /// Upload a file to Firebase Storage and return the permanent download URL.
  ///
  /// [file] — the file to upload.
  /// [originalFilename] — original name of the file.
  /// [universityId] — the university folder name for path scoping.
  /// [onProgress] — optional progress callback (0.0 to 1.0).
  Future<String> uploadFile({
    required File file,
    required String originalFilename,
    required String universityId,
    void Function(double progress)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw FileUploadException('Not signed in.');

    final bucketUrl = await _getActiveBucketUrl();
    if (bucketUrl == null || bucketUrl.isEmpty) {
      throw FileUploadException(
        'Storage is not configured yet. Contact the admin.',
      );
    }

    // Build a unique path inside the bucket
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = originalFilename.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final storagePath = 'uploads/$universityId/${user.uid}/${timestamp}_$safeName';

    // Get a FirebaseStorage instance pointing at the active bucket
    final storage = FirebaseStorage.instanceFor(bucket: bucketUrl);
    final ref = storage.ref().child(storagePath);

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: _mimeType(originalFilename),
        customMetadata: {
          'uploadedBy': user.uid,
          'originalName': originalFilename,
          'university': universityId,
        },
      ),
    );

    // Listen for progress
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }

    await uploadTask;
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }

  /// Guess MIME type from filename extension.
  String? _mimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Invalidate cached bucket URL (e.g. when admin switches bucket).
  void clearCache() {
    _cachedBucketUrl = null;
  }
}

class FileUploadException implements Exception {
  final String message;
  FileUploadException(this.message);
  @override
  String toString() => message;
}
