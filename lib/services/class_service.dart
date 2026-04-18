import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/class_model.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  String _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<List<ClassModel>> getClassesForUser(
    String uid, {
    String? universityId,
    bool fromCache = false,
  }) async {
    debugPrint(
      'CLASSSERVICE: getClassesForUser uid=$uid, universityId=$universityId, cache=$fromCache',
    );

    final getOpts = fromCache
        ? const GetOptions(source: Source.cache)
        : null;

    final membershipsSnapshot = fromCache
        ? await _firestore
            .collection('users')
            .doc(uid)
            .collection('memberships')
            .get(const GetOptions(source: Source.cache))
        : await _firestore
            .collection('users')
            .doc(uid)
            .collection('memberships')
            .get();

    debugPrint(
      'CLASSSERVICE: memberships count=${membershipsSnapshot.docs.length}',
    );

    final List<ClassModel> classes = [];

    final filteredDocs = universityId != null
        ? membershipsSnapshot.docs.where(
            (doc) => (doc.data()['universityId'] as String?) == universityId,
          )
        : membershipsSnapshot.docs;

    final futures = filteredDocs.map((membershipDoc) async {
      final classId = membershipDoc.id;
      final classDoc = fromCache
          ? await _firestore.collection('classes').doc(classId).get(getOpts!)
          : await _firestore.collection('classes').doc(classId).get();
      if (classDoc.exists && classDoc.data() != null) {
        return ClassModel.fromMap(classDoc.data()!, classDoc.id);
      }
      return null;
    });

    final results = await Future.wait(futures);
    classes.addAll(results.whereType<ClassModel>());

    return classes;
  }

  Future<ClassModel> createClass(
    String name,
    String universityId,
    String creatorUid,
  ) async {
    try {
      final classId = _uuid.v4();
      final classCode = _generateClassCode();
      final now = Timestamp.now();

      final newClass = ClassModel(
        classId: classId,
        classCode: classCode,
        name: name,
        universityId: universityId,
        creatorUid: creatorUid,
        writerUids: [creatorUid],
        createdAt: now,
        memberCount: 1,
      );

      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('classes').doc(classId),
        newClass.toMap(),
      );

      batch.set(
        _firestore
            .collection('users')
            .doc(creatorUid)
            .collection('memberships')
            .doc(classId),
        {'universityId': universityId, 'joinedAt': now, 'role': 'writer'},
      );

      await batch.commit();

      return newClass;
    } catch (e, stackTrace) {
      debugPrint('createClass error: $e \n $stackTrace');
      rethrow;
    }
  }

  Future<void> joinClassByCode(String code, String uid) async {
    final querySnapshot = await _firestore
        .collection('classes')
        .where('classCode', isEqualTo: code)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Class not found with code: $code');
    }

    final classDoc = querySnapshot.docs.first;
    final classId = classDoc.id;
    final universityId = classDoc.data()['universityId'] as String? ?? '';

    // Check if membership already exists to prevent overwriting role
    final membershipRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('memberships')
        .doc(classId);

    final existingMembership = await membershipRef.get();

    if (existingMembership.exists) {
      // User is already a member
      return;
    }

    final batch = _firestore.batch();

    // Create membership as reader
    batch.set(membershipRef, {
      'universityId': universityId,
      'joinedAt': Timestamp.now(),
      'role': 'reader',
    });

    // Increment member count in class document
    batch.update(classDoc.reference, {'memberCount': FieldValue.increment(1)});

    await batch.commit();
  }

  Future<String> getUserRole(String classId, String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('memberships')
          .doc(classId)
          .get();
      return doc.data()?['role'] as String? ?? 'reader';
    } catch (_) {
      return 'reader';
    }
  }

  Future<List<Map<String, dynamic>>> getWriters(String classId) async {
    final classDoc = await _firestore.collection('classes').doc(classId).get();
    if (!classDoc.exists) return [];

    final writerUids = List<String>.from(classDoc.data()?['writerUids'] ?? []);
    final List<Map<String, dynamic>> writers = [];

    for (final uid in writerUids) {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        writers.add({
          'uid': uid,
          'displayName': userDoc.data()?['displayName'] ?? 'Unknown User',
          'email': userDoc.data()?['email'] ?? '',
        });
      }
    }
    return writers;
  }

  Future<void> addWriterByEmail(String classId, String email) async {
    final usersSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (usersSnapshot.docs.isEmpty) {
      throw Exception('User not found with email: $email');
    }

    final userDoc = usersSnapshot.docs.first;
    final uid = userDoc.id;

    final classRef = _firestore.collection('classes').doc(classId);
    final classDoc = await classRef.get();
    if (!classDoc.exists) throw Exception('Class not found');

    final writerUids = List<String>.from(classDoc.data()?['writerUids'] ?? []);
    if (writerUids.length >= 6) {
      throw Exception('Maximum of 6 writers reached for this class.');
    }

    if (writerUids.contains(uid)) return;

    final batch = _firestore.batch();

    // Add to writerUids
    batch.update(classRef, {
      'writerUids': FieldValue.arrayUnion([uid]),
    });

    // Update membership role
    batch.update(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('memberships')
          .doc(classId),
      {'role': 'writer'},
    );

    await batch.commit();
  }

  Future<void> removeWriter(String classId, String uid) async {
    final classRef = _firestore.collection('classes').doc(classId);
    final classDoc = await classRef.get();
    if (!classDoc.exists) throw Exception('Class not found');

    if (classDoc.data()?['creatorUid'] == uid) {
      throw Exception(
        'The creator of the class cannot be removed as a writer.',
      );
    }

    final batch = _firestore.batch();

    // Remove from writerUids
    batch.update(classRef, {
      'writerUids': FieldValue.arrayRemove([uid]),
    });

    // Update membership role to reader
    batch.update(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('memberships')
          .doc(classId),
      {'role': 'reader'},
    );

    await batch.commit();
  }

  /// Leave a class — removes membership, writer role, and decrements member count.
  /// Throws if the user is the class creator (owners cannot leave their own class).
  Future<void> leaveClass(String classId, String uid) async {
    final classRef = _firestore.collection('classes').doc(classId);
    final classDoc = await classRef.get();
    if (!classDoc.exists) throw Exception('Class not found');

    if (classDoc.data()?['creatorUid'] == uid) {
      throw Exception('The class owner cannot leave. Delete the class instead.');
    }

    final batch = _firestore.batch();

    // Remove membership sub-document
    batch.delete(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('memberships')
          .doc(classId),
    );

    // Remove from writerUids (no-op if not a writer)
    batch.update(classRef, {
      'writerUids': FieldValue.arrayRemove([uid]),
      'memberCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  Future<void> deleteClass(String classId) async {
    // Note: This only deletes the Firestore record.
    // GitHub folders are preserved for safety and can be manually cleared if needed.
    await _firestore.collection('classes').doc(classId).delete();
  }
}
