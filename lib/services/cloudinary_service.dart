import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for uploading images to Cloudinary.
///
/// Reads credentials from Firestore `config/cloudinary` document which should
/// contain `cloud_name` and `upload_preset` fields.
class CloudinaryService {
  static final CloudinaryService instance = CloudinaryService._();
  CloudinaryService._();

  String? _cloudName;
  String? _uploadPreset;
  bool _initialized = false;

  final Dio _dio = Dio();

  /// Load Cloudinary credentials from Firestore.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('cloudinary')
          .get();
      if (doc.exists && doc.data() != null) {
        _cloudName = doc.data()!['cloud_name'] as String?;
        _uploadPreset = doc.data()!['upload_preset'] as String?;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to load Cloudinary config: $e');
    }
  }

  /// Whether the service is configured and ready.
  Future<bool> get isReady async {
    await _ensureInitialized();
    return _cloudName != null && _uploadPreset != null;
  }

  /// Upload an image file to Cloudinary.
  ///
  /// [imageFile] — the local file to upload.
  /// [folder] — optional Cloudinary folder path (e.g. 'events/banners').
  ///
  /// Returns the secure URL of the uploaded image, or null on failure.
  Future<String?> uploadImage(File imageFile, {String folder = 'events'}) async {
    await _ensureInitialized();
    if (_cloudName == null || _uploadPreset == null) {
      debugPrint('Cloudinary not configured');
      return null;
    }

    try {
      final url = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
        'upload_preset': _uploadPreset,
        'folder': folder,
      });

      final response = await _dio.post(url, data: formData);

      if (response.statusCode == 200 && response.data != null) {
        return response.data['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload failed: $e');
      return null;
    }
  }
}
