import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  bool? _isWriter;
  String? _cachedUid;

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<bool> isWriter() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    if (_cachedUid != user.uid) {
      _isWriter = null;
      _cachedUid = user.uid;
    }

    if (_isWriter != null) {
      return _isWriter!;
    }

    if (!await _isOnline()) {
      return false;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _isWriter = doc.exists && doc.data()?['role'] == 'writer';
      return _isWriter!;
    } catch (e) {
      _isWriter = false;
      return false;
    }
  }

  void clearCache() {
    _isWriter = null;
    _cachedUid = null;
  }
}
