import 'package:cloud_firestore/cloud_firestore.dart';

class ClassMembershipModel {
  final String classId;
  final String universityId;
  final Timestamp joinedAt;
  final String role; // "reader" or "writer"

  ClassMembershipModel({
    required this.classId,
    required this.universityId,
    required this.joinedAt,
    required this.role,
  });

  factory ClassMembershipModel.fromMap(Map<String, dynamic> data, String classIdDocument) {
    return ClassMembershipModel(
      classId: classIdDocument,
      universityId: data['universityId'] ?? '',
      joinedAt: data['joinedAt'] as Timestamp? ?? Timestamp.now(),
      role: data['role'] ?? 'reader',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'universityId': universityId,
      'joinedAt': joinedAt,
      'role': role,
    };
  }
}
