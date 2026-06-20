import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_invite_model.dart';
import '../models/group_member_model.dart';
import '../models/join_request_model.dart';
import '../services/invite_service.dart';
import 'auth_provider.dart';
import 'group_detail_provider.dart';

// ─── Service Provider ─────────────────────────────────────────────────────

final inviteServiceProvider = Provider<InviteService>((ref) => InviteService());

// ─── Invite States ────────────────────────────────────────────────────────

sealed class InviteState {
  const InviteState();
}

class InviteIdle extends InviteState {
  const InviteIdle();
}

class InviteLoading extends InviteState {
  const InviteLoading();
}

class InviteCodeGenerated extends InviteState {
  final String inviteCode;
  const InviteCodeGenerated(this.inviteCode);
}

class InviteSuccess extends InviteState {
  final String message;
  final String groupId;
  final String groupName;
  final String groupIcon;
  const InviteSuccess({
    required this.message,
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
  });
}

class InviteFailure extends InviteState {
  final String message;
  const InviteFailure(this.message);
}

// ─── Invite Notifier ──────────────────────────────────────────────────────

class InviteNotifier extends Notifier<InviteState> {
  @override
  InviteState build() => const InviteIdle();

  /// Generate invite code for a group
  Future<void> generateInviteCode(String groupId) async {
    final authState = ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) {
      state = const InviteFailure('You must be signed in');
      return;
    }

    state = const InviteLoading();

    try {
      final service = ref.read(inviteServiceProvider);
      final inviteCode = await service.createGroupInvite(
        groupId: groupId,
        createdBy: authState.user.uid,
      );
      state = InviteCodeGenerated(inviteCode);
    } catch (e) {
      state = InviteFailure('Failed to generate invite: ${e.toString()}');
    }
  }

  /// Join a group using an invite code
  Future<void> joinGroupViaInvite(String inviteCode) async {
    final authState = ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) {
      state = const InviteFailure('You must be signed in');
      return;
    }

    state = const InviteLoading();

    try {
      final service = ref.read(inviteServiceProvider);
      final user = authState.user;
      
      final result = await service.joinGroupViaInvite(
        inviteCode: inviteCode.trim().toUpperCase(),
        userId: user.uid,
        userName: user.name,
        userAvatar: user.avatar,
        userPhone: user.phone,
      );

      if (result['success'] == true) {
        state = InviteSuccess(
          message: result['message'],
          groupId: result['groupId'],
          groupName: result['groupName'],
          groupIcon: result['groupIcon'],
        );
      } else {
        state = InviteFailure(result['message']);
      }
    } catch (e) {
      state = InviteFailure('Failed to join group: ${e.toString()}');
    }
  }

  /// Verify an invite code without joining
  Future<GroupInviteModel?> verifyInviteCode(String inviteCode) async {
    try {
      final service = ref.read(inviteServiceProvider);
      return await service.verifyInviteCode(inviteCode.trim().toUpperCase());
    } catch (e) {
      return null;
    }
  }

  /// Get active invite code for a group
  Future<String?> getActiveInviteCode(String groupId) async {
    try {
      final service = ref.read(inviteServiceProvider);
      return await service.getActiveInviteCode(groupId);
    } catch (e) {
      return null;
    }
  }

  void reset() => state = const InviteIdle();
}

final inviteProvider = NotifierProvider<InviteNotifier, InviteState>(
  InviteNotifier.new,
);

// ─── Group Members Stream ─────────────────────────────────────────────────

final groupMembersProvider = StreamProvider.autoDispose.family<List<GroupMemberModel>, String>((ref, groupId) {
  final service = ref.read(inviteServiceProvider);
  return service.watchGroupMembers(groupId);
});

// ─── Join Requests Streams ────────────────────────────────────────────────

/// Streams total unread pending join requests for all groups the logged-in user admin-manages.
final adminPendingRequestsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  if (authState is! AuthAuthenticated) return Stream.value(0);
  final uid = authState.user.uid;
  
  final groupsAsync = ref.watch(userGroupsProvider);
  return groupsAsync.when(
    data: (groups) {
      // Find UIDs of groups where this user is the creator/admin
      final adminGroupIds = groups
          .where((g) => g.createdBy == uid)
          .map((g) => g.id)
          .toList();
      
      if (adminGroupIds.isEmpty) return Stream.value(0);
      
      // Query pending requests for those admin groups in real time
      return FirebaseFirestore.instance
          .collection('joinRequests')
          .where('status', isEqualTo: 'pending')
          .where('groupId', whereIn: adminGroupIds)
          .snapshots()
          .map((snap) => snap.docs.length);
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

/// Streams pending requests for a specific group.
final pendingGroupRequestsProvider = StreamProvider.autoDispose.family<List<JoinRequestModel>, String>((ref, groupId) {
  final service = ref.read(inviteServiceProvider);
  return service.watchPendingRequests(groupId);
});
