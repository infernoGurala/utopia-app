import 'package:cloud_firestore/cloud_firestore.dart';

class UniversityModel {
  final String id;
  final String name;
  final String shortName;

  UniversityModel({
    required this.id,
    required this.name,
    required this.shortName,
  });

  factory UniversityModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UniversityModel(
      id: documentId,
      name: data['name'] ?? '',
      shortName: data['shortName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'shortName': shortName,
    };
  }
}
