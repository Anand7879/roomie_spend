import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Database service class interfacing with Cloud Firestore.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Fetches user document from Firestore. Returns null only if the document
  /// genuinely does not exist. Rethrows all other errors (network, permissions)
  /// so the calling provider can surface them to the user.
  Future<RoommateUser?> getUser(String uid) async {
    try {
      final docSnapshot = await _usersCollection.doc(uid).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return RoommateUser.fromMap(docSnapshot.data()!, docSnapshot.id);
      }
      return null; // Document genuinely does not exist
    } catch (e, stackTrace) {
      debugPrint('FirestoreService.getUser($uid) error: $e\n$stackTrace');
      rethrow; // Let auth_provider handle and surface to the user
    }
  }

  /// Writes user model data into Firestore document users/{uid}
  Future<void> createUser(RoommateUser user) async {
    await _usersCollection.doc(user.uid).set(user.toMap());
  }
}
