import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  bool? _isSuperUser;
  String? _cachedUid;

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Check whether the current user has the "superuser" role.
  /// Super users get access to the Admin Control Panel, library management,
  /// editing the About UTOPIA / Rollout Releases section, and note editing
  /// outside of class-scoped writer roles.
  Future<bool> isSuperUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    if (_cachedUid != user.uid) {
      _isSuperUser = null;
      _cachedUid = user.uid;
    }

    if (_isSuperUser != null) {
      return _isSuperUser!;
    }

    if (!await _isOnline()) {
      return false;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _isSuperUser = doc.exists && doc.data()?['role'] == 'superuser';
      return _isSuperUser!;
    } catch (e) {
      _isSuperUser = false;
      return false;
    }
  }



  void clearCache() {
    _isSuperUser = null;
    _cachedUid = null;
  }
}
