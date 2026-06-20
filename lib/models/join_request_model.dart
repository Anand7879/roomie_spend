import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a user's request to join a roommate group.
class JoinRequestModel {
  final String requestId;
  final String groupId;
  final String groupName;
  final String requestedBy;
  final String requestedUserName;
  final String requestedUserPhoto;
  final String requestedPhone;
  final DateTime requestedAt;
  final String status; // 'pending' | 'approved' | 'denied'
  final DateTime createdAt;
  final DateTime updatedAt;

  JoinRequestModel({
    required this.requestId,
    required this.groupId,
    required this.groupName,
    required this.requestedBy,
    required this.requestedUserName,
    required this.requestedUserPhoto,
    required this.requestedPhone,
    required this.requestedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JoinRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return JoinRequestModel(
      requestId: docId,
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      requestedUserName: map['requestedUserName'] ?? '',
      requestedUserPhoto: map['requestedUserPhoto'] ?? '',
      requestedPhone: map['requestedPhone'] ?? '',
      requestedAt: (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'requestedBy': requestedBy,
      'requestedUserName': requestedUserName,
      'requestedUserPhoto': requestedUserPhoto,
      'requestedPhone': requestedPhone,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  JoinRequestModel copyWith({
    String? status,
    DateTime? updatedAt,
  }) {
    return JoinRequestModel(
      requestId: requestId,
      groupId: groupId,
      groupName: groupName,
      requestedBy: requestedBy,
      requestedUserName: requestedUserName,
      requestedUserPhoto: requestedUserPhoto,
      requestedPhone: requestedPhone,
      requestedAt: requestedAt,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
