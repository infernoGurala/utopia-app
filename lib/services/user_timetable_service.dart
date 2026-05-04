import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:utopia_app/models/user_timetable.dart';

class UserTimetableService {
  static DocumentReference<Map<String, dynamic>> _docRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('timetable');
  }

  static Future<UserTimetable?> getTimetable() async {
    try {
      final doc = await _docRef().get();
      if (doc.exists && doc.data() != null) {
        return UserTimetable.fromJson(doc.data()!);
      }
    } catch (e) {
      // Ignored
    }
    return null;
  }

  static Future<void> saveTimetable(UserTimetable timetable) async {
    await _docRef().set(timetable.toJson());
  }

  static Future<void> deleteTimetable() async {
    await _docRef().delete();
  }
}
