import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/group_invite_model.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

/// Service for managing group invitations, QR codes, and invite links.
class InviteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  static const String _invitePrefix = 'RMSP';
  static const int _inviteDays = 7;

  // ─── Generate Invite Code ────────────────────────────────────────────────

  /// Generates a secure random invite code in format: RMSP-XXXX
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final code = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '$_invitePrefix-$code';
  }

  // ─── Create Group Invite ──────────────────────────────────────────────────

  /// Creates a new invitation for a group. Returns the invite code.
  Future<String> createGroupInvite({
    required String groupId,
    required String createdBy,
  }) async {
    try {
      // Check if an active invite already exists for this group
      final existingInvites = await _db
          .collection('groupInvites')
          .where('groupId', isEqualTo: groupId)
          .where('used', isEqualTo: false)
          .get();

      // Check if any of the existing invites are still valid
      for (final doc in existingInvites.docs) {
        final invite = GroupInviteModel.fromMap(doc.data(), doc.id);
        if (invite.isValid) {
          return invite.inviteCode;
        }
      }

      // Generate new invite code
      final inviteCode = _generateInviteCode();
      final expiresAt = DateTime.now().add(const Duration(days: _inviteDays));

      final invite = GroupInviteModel(
        id: '',
        groupId: groupId,
        inviteCode: inviteCode,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        used: false,
      );

      await _db.collection('groupInvites').add(invite.toMap());
      return inviteCode;
    } catch (e, st) {
      debugPrint('InviteService.createGroupInvite error: $e\n$st');
      rethrow;
    }
  }

  // ─── Verify Invite Code ───────────────────────────────────────────────────

  /// Verifies an invite code and returns the associated invite.
  Future<GroupInviteModel?> verifyInviteCode(String inviteCode) async {
    try {
      final snapshot = await _db
          .collection('groupInvites')
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final invite = GroupInviteModel.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );

      return invite;
    } catch (e, st) {
      debugPrint('InviteService.verifyInviteCode error: $e\n$st');
      rethrow;
    }
  }

  // ─── Join Group via Invite ────────────────────────────────────────────────

  /// Joins a user to a group using a valid invite code.
  /// Returns a map with success status and message.
  Future<Map<String, dynamic>> joinGroupViaInvite({
    required String inviteCode,
    required String userId,
    required String userName,
    required String userAvatar,
    required String userPhone,
  }) async {
    try {
      // Verify invite code
      final invite = await verifyInviteCode(inviteCode);

      if (invite == null) {
        return {
          'success': false,
          'message': 'Invalid invite code',
        };
      }

      if (!invite.isValid) {
        return {
          'success': false,
          'message': invite.used ? 'Invite code already used' : 'Invite code expired',
        };
      }

      // Get group details
      final groupDoc = await _db.collection('groups').doc(invite.groupId).get();
      
      if (!groupDoc.exists) {
        return {
          'success': false,
          'message': 'Group not found',
        };
      }

      final groupData = groupDoc.data()!;
      final group = GroupModel.fromMap(groupData, groupDoc.id);

      // Check if group is archived
      if (group.isArchived) {
        return {
          'success': false,
          'message': 'Cannot join archived group',
        };
      }

      // Check if user is already a member
      if (group.members.contains(userId)) {
        return {
          'success': false,
          'message': 'You are already a member of this group',
        };
      }

      // Use batch to ensure atomicity
      final batch = _db.batch();

      // Add user to group members
      final groupRef = _db.collection('groups').doc(invite.groupId);
      batch.update(groupRef, {
        'members': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create group member document
      final memberRef = _db
          .collection('groups')
          .doc(invite.groupId)
          .collection('members')
          .doc(userId);
      
      final member = GroupMemberModel(
        id: userId,
        groupId: invite.groupId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        userPhone: userPhone,
        role: 'member',
        joinedAt: DateTime.now(),
        invitedBy: invite.createdBy,
      );
      
      batch.set(memberRef, member.toMap());

      // Mark invite as used
      final inviteRef = _db.collection('groupInvites').doc(invite.id);
      batch.update(inviteRef, {
        'used': true,
        'usedBy': userId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Create activity log
      final activityRef = _db.collection('activities').doc();
      batch.set(activityRef, {
        'userId': userId,
        'type': 'member_joined',
        'title': '$userName joined the group',
        'description': group.groupName,
        'groupName': group.groupName,
        'groupId': invite.groupId,
        'amount': null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        'success': true,
        'message': 'Successfully joined group',
        'groupId': invite.groupId,
        'groupName': group.groupName,
        'groupIcon': group.groupIcon,
      };
    } catch (e, st) {
      debugPrint('InviteService.joinGroupViaInvite error: $e\n$st');
      return {
        'success': false,
        'message': 'Failed to join group: ${e.toString()}',
      };
    }
  }

  // ─── Get Group Members ────────────────────────────────────────────────────

  /// Stream of group members
  Stream<List<GroupMemberModel>> watchGroupMembers(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupMemberModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── Get Active Invite for Group ──────────────────────────────────────────

  /// Gets the active invite code for a group (if exists and valid)
  Future<String?> getActiveInviteCode(String groupId) async {
    try {
      final snapshot = await _db
          .collection('groupInvites')
          .where('groupId', isEqualTo: groupId)
          .where('used', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        final invite = GroupInviteModel.fromMap(doc.data(), doc.id);
        if (invite.isValid) {
          return invite.inviteCode;
        }
      }

      return null;
    } catch (e, st) {
      debugPrint('InviteService.getActiveInviteCode error: $e\n$st');
      return null;
    }
  }

  // ─── Generate Invite Link ─────────────────────────────────────────────────

  /// Generates a deep link for the invite code
  String generateInviteLink(String inviteCode) {
    // TODO: Replace with your actual deep link domain
    return 'https://roomiespend.app/invite/$inviteCode';
  }

  /// Generates shareable text for an invite
  String generateShareText(String inviteCode, String groupName) {
    return '''
Join my RoomieSpend group "$groupName"!

Invite Code: $inviteCode

Download the app and use this code to join:
https://roomiespend.app/invite/$inviteCode

Split expenses together effortlessly! 💰
''';
  }
}
