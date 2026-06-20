import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/group_invite_model.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/join_request_model.dart';
import '../models/activity_model.dart';

/// Service for managing group invitations, QR codes, and invite links.
class InviteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      // 1. Verify invite code (Query outside transaction since queries are not supported inside transactions)
      final invite = await verifyInviteCode(inviteCode);

      if (invite == null) {
        return {
          'success': false,
          'message': 'Invalid invite code.',
        };
      }

      // Pre-transaction sanity validation
      if (invite.used) {
        return {
          'success': false,
          'message': 'This invite has already been used.',
        };
      }

      if (invite.expiresAt.isBefore(DateTime.now())) {
        return {
          'success': false,
          'message': 'This invite has expired.',
        };
      }

      final inviteRef = _db.collection('groupInvites').doc(invite.id);
      final groupRef = _db.collection('groups').doc(invite.groupId);
      final memberRef = groupRef.collection('members').doc(userId);
      final activityRef = _db.collection('activities').doc();

      // Run everything inside a Firestore Transaction
      final joinResult = await _db.runTransaction<Map<String, dynamic>>((transaction) async {
        // Read invite document to ensure it remains unused (concurrency check)
        final inviteSnapshot = await transaction.get(inviteRef);
        if (!inviteSnapshot.exists) {
          throw Exception('Invalid invite code.');
        }

        final inviteData = inviteSnapshot.data()!;
        final currentUsed = inviteData['used'] as bool? ?? false;
        if (currentUsed) {
          throw Exception('This invite has already been used.');
        }

        final expiresAtTimestamp = inviteData['expiresAt'] as Timestamp?;
        if (expiresAtTimestamp != null && expiresAtTimestamp.toDate().isBefore(DateTime.now())) {
          throw Exception('This invite has expired.');
        }

        // Read group document
        final groupSnapshot = await transaction.get(groupRef);
        if (!groupSnapshot.exists) {
          throw Exception('This group no longer exists.');
        }

        final groupData = groupSnapshot.data()!;
        final group = GroupModel.fromMap(groupData, groupSnapshot.id);

        if (group.isArchived) {
          throw Exception('Cannot join archived group.');
        }

        // Check if user is already a member (Step 5)
        if (group.members.contains(userId)) {
          throw Exception('You are already in this group.');
        }

        // --- Writes inside transaction ---

        // 1. Update group document
        // Write members, memberCount, updatedAt, and joinInviteId for rules validation
        transaction.update(groupRef, {
          'members': FieldValue.arrayUnion([userId]),
          'memberCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
          'joinInviteId': invite.id,
        });

        // 2. Create group member document
        // Pass inviteId for rules validation
        final memberMap = {
          'groupId': invite.groupId,
          'userId': userId,
          'userName': userName,
          'userAvatar': userAvatar,
          'userPhone': userPhone,
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'invitedBy': invite.createdBy,
          'inviteId': invite.id,
        };
        transaction.set(memberRef, memberMap);

        // 3. Mark invite as used
        transaction.update(inviteRef, {
          'used': true,
          'usedBy': userId,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // 4. Create activity log
        transaction.set(activityRef, {
          'userId': userId,
          'type': 'member_joined',
          'title': '$userName joined the group',
          'description': group.groupName,
          'groupName': group.groupName,
          'groupId': invite.groupId,
          'amount': null,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'message': 'Successfully joined group',
          'groupId': invite.groupId,
          'groupName': group.groupName,
          'groupIcon': group.groupIcon,
        };
      });

      return joinResult;
    } on FirebaseException catch (e, st) {
      debugPrint('InviteService.joinGroupViaInvite FirebaseException: $e\n$st');
      String friendlyMessage = 'Failed to join group: ${e.message}';
      if (e.code == 'permission-denied') {
        friendlyMessage = "You don't have permission to join this group.";
      } else if (e.code == 'unavailable') {
        friendlyMessage = "Please check your internet connection.";
      }
      return {
        'success': false,
        'message': friendlyMessage,
      };
    } catch (e, st) {
      debugPrint('InviteService.joinGroupViaInvite error: $e\n$st');
      String friendlyMessage = e.toString();
      if (friendlyMessage.startsWith('Exception:')) {
        friendlyMessage = friendlyMessage.replaceFirst('Exception:', '').trim();
      }
      return {
        'success': false,
        'message': friendlyMessage,
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

  // ─── Join Requests ────────────────────────────────────────────────────────

  /// Creates a join request for a group and logs it as an activity for the admin.
  Future<void> createJoinRequest({
    required String groupId,
    required String groupName,
    required String requestedBy,
    required String requestedUserName,
    required String requestedUserPhoto,
    required String requestedPhone,
    required String adminUid,
  }) async {
    try {
      // Check if a pending request already exists
      final existing = await _db
          .collection('joinRequests')
          .where('groupId', isEqualTo: groupId)
          .where('requestedBy', isEqualTo: requestedBy)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return; // Already pending
      }

      final batch = _db.batch();
      final requestRef = _db.collection('joinRequests').doc();
      final activityRef = _db.collection('activities').doc();

      final request = JoinRequestModel(
        requestId: requestRef.id,
        groupId: groupId,
        groupName: groupName,
        requestedBy: requestedBy,
        requestedUserName: requestedUserName,
        requestedUserPhoto: requestedUserPhoto,
        requestedPhone: requestedPhone,
        requestedAt: DateTime.now(),
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      batch.set(requestRef, request.toMap());

      // Log request activity (sent to group admin's feed)
      batch.set(activityRef, {
        'userId': adminUid,
        'type': ActivityType.joinRequestCreated.toDbString(),
        'title': '$requestedUserName requested to join group "$groupName"',
        'description': 'Tap to view request in settings.',
        'groupName': groupName,
        'groupId': groupId,
        'amount': null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e, st) {
      debugPrint('InviteService.createJoinRequest error: $e\n$st');
      rethrow;
    }
  }

  /// Re-submits a denied join request to pending status.
  Future<void> reSubmitJoinRequest(String requestId) async {
    try {
      final doc = await _db.collection('joinRequests').doc(requestId).get();
      if (!doc.exists) return;
      final request = JoinRequestModel.fromMap(doc.data()!, doc.id);
      
      final groupDoc = await _db.collection('groups').doc(request.groupId).get();
      if (!groupDoc.exists) return;
      final group = GroupModel.fromMap(groupDoc.data()!, groupDoc.id);

      final batch = _db.batch();
      final requestRef = _db.collection('joinRequests').doc(requestId);
      final activityRef = _db.collection('activities').doc();

      batch.update(requestRef, {
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log request activity again for admin
      batch.set(activityRef, {
        'userId': group.createdBy,
        'type': ActivityType.joinRequestCreated.toDbString(),
        'title': '${request.requestedUserName} requested to join group "${request.groupName}"',
        'description': 'Tap to view request in settings.',
        'groupName': request.groupName,
        'groupId': request.groupId,
        'amount': null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e, st) {
      debugPrint('InviteService.reSubmitJoinRequest error: $e\n$st');
      rethrow;
    }
  }

  /// Real-time stream of pending requests for a group.
  Stream<List<JoinRequestModel>> watchPendingRequests(String groupId) {
    return _db
        .collection('joinRequests')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => JoinRequestModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Real-time stream of the current request status for a user and a group.
  Stream<JoinRequestModel?> watchRequestStatus(String groupId, String userId) {
    return _db
        .collection('joinRequests')
        .where('groupId', isEqualTo: groupId)
        .where('requestedBy', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          // Return the most recently updated request
          final list = snap.docs
              .map((d) => JoinRequestModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list.first;
        });
  }

  /// Transactionally approves a join request.
  Future<Map<String, dynamic>> approveJoinRequest({
    required String requestId,
    required String adminUid,
    required String adminName,
  }) async {
    try {
      final requestRef = _db.collection('joinRequests').doc(requestId);
      
      final joinResult = await _db.runTransaction<Map<String, dynamic>>((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);
        if (!requestSnapshot.exists) {
          throw Exception('Join request no longer exists.');
        }
        
        final requestData = requestSnapshot.data()!;
        final status = requestData['status'] as String? ?? 'pending';
        if (status != 'pending') {
          throw Exception('Request is no longer pending.');
        }
        
        final groupId = requestData['groupId'] as String? ?? '';
        final requestedBy = requestData['requestedBy'] as String? ?? '';
        final requestedUserName = requestData['requestedUserName'] as String? ?? '';
        final requestedUserPhoto = requestData['requestedUserPhoto'] as String? ?? '';
        final requestedPhone = requestData['requestedPhone'] as String? ?? '';
        final groupName = requestData['groupName'] as String? ?? '';
        
        final groupRef = _db.collection('groups').doc(groupId);
        final memberRef = groupRef.collection('members').doc(requestedBy);
        final activityRef = _db.collection('activities').doc();
        final notificationRef = _db.collection('activities').doc();
        
        // Read group document
        final groupSnapshot = await transaction.get(groupRef);
        if (!groupSnapshot.exists) {
          throw Exception('Group no longer exists.');
        }
        
        final groupData = groupSnapshot.data()!;
        final membersList = List<String>.from(groupData['members'] as List? ?? []);
        final currentGroupIcon = groupData['groupIcon'] as String? ?? '👥';
        
        if (membersList.contains(requestedBy)) {
          throw Exception('User is already a member of this group.');
        }
        
        // --- Writes ---
        // 1. Update group members and count
        transaction.update(groupRef, {
          'members': FieldValue.arrayUnion([requestedBy]),
          'memberCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // 2. Create member subcollection document
        transaction.set(memberRef, {
          'groupId': groupId,
          'userId': requestedBy,
          'userName': requestedUserName,
          'userAvatar': requestedUserPhoto,
          'userPhone': requestedPhone,
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'invitedBy': adminUid,
        });
        
        // 3. Mark request as approved
        transaction.update(requestRef, {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // 4. Create activity log for admin/group
        transaction.set(activityRef, {
          'userId': adminUid,
          'type': ActivityType.joinRequestApproved.toDbString(),
          'title': 'Approved $requestedUserName to join group "$groupName"',
          'description': groupName,
          'groupName': groupName,
          'groupId': groupId,
          'amount': null,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // 5. Create notification activity for approved user
        transaction.set(notificationRef, {
          'userId': requestedBy,
          'type': ActivityType.memberJoined.toDbString(),
          'title': 'Approved to join group "$groupName"',
          'description': 'You are now a member of the group!',
          'groupName': groupName,
          'groupId': groupId,
          'amount': null,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        return {
          'success': true,
          'message': 'Successfully approved request',
          'groupId': groupId,
          'groupName': groupName,
          'groupIcon': currentGroupIcon,
        };
      });
      
      return joinResult;
    } catch (e) {
      debugPrint('ApproveJoinRequest error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception:', '').trim(),
      };
    }
  }

  /// Transactionally denies a join request.
  Future<Map<String, dynamic>> denyJoinRequest({
    required String requestId,
    required String adminUid,
  }) async {
    try {
      final requestRef = _db.collection('joinRequests').doc(requestId);
      
      final result = await _db.runTransaction<Map<String, dynamic>>((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);
        if (!requestSnapshot.exists) {
          throw Exception('Join request no longer exists.');
        }
        
        final requestData = requestSnapshot.data()!;
        final status = requestData['status'] as String? ?? 'pending';
        if (status != 'pending') {
          throw Exception('Request is no longer pending.');
        }

        final groupId = requestData['groupId'] as String? ?? '';
        final requestedBy = requestData['requestedBy'] as String? ?? '';
        final requestedUserName = requestData['requestedUserName'] as String? ?? '';
        final groupName = requestData['groupName'] as String? ?? '';
        
        final activityRef = _db.collection('activities').doc();
        final notificationRef = _db.collection('activities').doc();
        
        // --- Writes ---
        // 1. Mark request as denied
        transaction.update(requestRef, {
          'status': 'denied',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // 2. Create activity log for admin/group
        transaction.set(activityRef, {
          'userId': adminUid,
          'type': ActivityType.joinRequestDenied.toDbString(),
          'title': "Denied $requestedUserName's join request to \"$groupName\"",
          'description': groupName,
          'groupName': groupName,
          'groupId': groupId,
          'amount': null,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // 3. Create notification activity for requester
        transaction.set(notificationRef, {
          'userId': requestedBy,
          'type': ActivityType.expenseDeleted.toDbString(),
          'title': 'Request to join group "$groupName" declined',
          'description': 'Contact the group admin for details.',
          'groupName': groupName,
          'groupId': groupId,
          'amount': null,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        return {
          'success': true,
          'message': 'Request denied successfully',
        };
      });
      
      return result;
    } catch (e) {
      debugPrint('DenyJoinRequest error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception:', '').trim(),
      };
    }
  }
}
