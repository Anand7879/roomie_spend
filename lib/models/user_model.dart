import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a RoomieSpend user profile model mapped to local secure storage
/// and the Cloud Firestore database.
class RoommateUser {
  final String uid;
  final String phone;
  final String name;
  final String email;
  final String avatar;
  final String referralCode;
  final bool profileCompleted;
  final DateTime createdAt;

  RoommateUser({
    required this.uid,
    required this.phone,
    required this.name,
    required this.email,
    required this.avatar,
    required this.referralCode,
    required this.profileCompleted,
    required this.createdAt,
  });

  /// Maps Firestore document map back into RoommateUser object
  factory RoommateUser.fromMap(Map<String, dynamic> map, String docId) {
    return RoommateUser(
      uid: docId,
      phone: map['phone'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      avatar: map['avatar'] ?? '',
      referralCode: map['referralCode'] ?? '',
      profileCompleted: map['profileCompleted'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Maps RoommateUser to database write map.
  /// Note: 'uid' is intentionally excluded — it is stored as the Firestore
  /// document ID (users/{uid}), not duplicated inside the document body.
  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'name': name,
      'email': email,
      'avatar': avatar,
      'referralCode': referralCode,
      'profileCompleted': profileCompleted,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Helper to convert user values into local key-value strings for SecureStorage
  Map<String, String> toLocalMap() {
    return {
      'uid': uid,
      'phone': phone,
      'name': name,
      'email': email,
    };
  }
}
