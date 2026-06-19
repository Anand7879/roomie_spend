import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a group invitation with secure code and expiration.
class GroupInviteModel {
  final String id;
  final String groupId;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;
  final String? usedBy;
  final DateTime? joinedAt;
  final String? role;

  GroupInviteModel({
    required this.id,
    required this.groupId,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
    this.usedBy,
    this.joinedAt,
    this.role = 'member',
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !used && !isExpired;

  factory GroupInviteModel.fromMap(Map<String, dynamic> map, String docId) {
    return GroupInviteModel(
      id: docId,
      groupId: map['groupId'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 7)),
      used: map['used'] as bool? ?? false,
      usedBy: map['usedBy'] as String?,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
      role: map['role'] as String? ?? 'member',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': used,
      'usedBy': usedBy,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
      'role': role,
    };
  }

  GroupInviteModel copyWith({
    String? id,
    String? groupId,
    String? inviteCode,
    String? createdBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? used,
    String? usedBy,
    DateTime? joinedAt,
    String? role,
  }) {
    return GroupInviteModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      used: used ?? this.used,
      usedBy: usedBy ?? this.usedBy,
      joinedAt: joinedAt ?? this.joinedAt,
      role: role ?? this.role,
    );
  }
}
