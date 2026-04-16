import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/university_model.dart';

class UniversityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UniversityModel>> fetchAllUniversities() async {
    try {
      final response = await http.get(Uri.parse('http://universities.hipolabs.com/search?country=India'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<UniversityModel> result = [];
        
        for (var item in data) {
          final String name = item['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          
          final String slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
          final String id = slug.replaceAll(RegExp(r'\s+'), '-');
          final String shortName = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).join('');
          
          result.add(UniversityModel(id: id, name: name, shortName: shortName));
        }
        
        result.sort((a, b) => a.name.compareTo(b.name));
        return result;
      }
    } catch (_) {
      // Do not crash, fall through to return empty list
    }
    return [];
  }

  Future<String?> getUserSelectedUniversity(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['selectedUniversityId'] as String?;
    }
    return null;
  }

  Future<void> setUserSelectedUniversity(String uid, String universityId) async {
    await _firestore.collection('users').doc(uid).set({
      'selectedUniversityId': universityId,
    }, SetOptions(merge: true));
  }
}
