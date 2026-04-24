import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String classId;
  final String classCode;
  final String name;
  final String universityId;
  final String creatorUid;
  final List<String> writerUids;
  final List<String> memberUids;
  final Timestamp createdAt;
  final int memberCount;

  ClassModel({
    required this.classId,
    required this.classCode,
    required this.name,
    required this.universityId,
    required this.creatorUid,
    required this.writerUids,
    required this.memberUids,
    required this.createdAt,
    required this.memberCount,
  });

  factory ClassModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ClassModel(
      classId: documentId,
      classCode: data['classCode'] ?? '',
      name: data['name'] ?? '',
      universityId: data['universityId'] ?? '',
      creatorUid: data['creatorUid'] ?? '',
      writerUids: List<String>.from(data['writerUids'] ?? []),
      memberUids: List<String>.from(data['memberUids'] ?? []),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      memberCount: data['memberCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classCode': classCode,
      'name': name,
      'universityId': universityId,
      'creatorUid': creatorUid,
      'writerUids': writerUids,
      'memberUids': memberUids,
      'createdAt': createdAt,
      'memberCount': memberCount,
    };
  }
}
