import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a member of a group with role and join metadata.
class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String userPhone;
  final String role;
  final DateTime joinedAt;
  final String? invitedBy;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.userPhone,
    this.role = 'member',
    required this.joinedAt,
    this.invitedBy,
  });

  bool get isAdmin => role == 'admin';
  bool get isOwner => role == 'owner';

  factory GroupMemberModel.fromMap(Map<String, dynamic> map, String docId) {
    return GroupMemberModel(
      id: docId,
      groupId: map['groupId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userAvatar: map['userAvatar'] as String? ?? '👤',
      userPhone: map['userPhone'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      invitedBy: map['invitedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userPhone': userPhone,
      'role': role,
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': invitedBy,
    };
  }
}
