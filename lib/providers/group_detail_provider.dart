import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/group_firestore_service.dart';
import 'auth_provider.dart';

// ─── Service Provider ─────────────────────────────────────────────────────

final groupFirestoreServiceProvider =
    Provider<GroupFirestoreService>((ref) => GroupFirestoreService());

// ─── User Groups Stream ───────────────────────────────────────────────────

/// Real-time stream of groups the signed-in user belongs to.
final userGroupsProvider =
    StreamProvider.autoDispose<List<GroupModel>>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  if (authState is! AuthAuthenticated) return Stream.value([]);
  final uid = authState.user.uid;
  return ref.read(groupFirestoreServiceProvider).watchUserGroups(uid);
});

/// Real-time stream of a single group by ID.
final groupDetailProvider =
    StreamProvider.autoDispose.family<GroupModel?, String>((ref, groupId) {
  return ref.read(groupFirestoreServiceProvider).watchGroup(groupId);
});

// ─── Create Group Notifier ────────────────────────────────────────────────

sealed class CreateGroupState {
  const CreateGroupState();
}

class CreateGroupIdle extends CreateGroupState {
  const CreateGroupIdle();
}

class CreateGroupLoading extends CreateGroupState {
  const CreateGroupLoading();
}

class CreateGroupSuccess extends CreateGroupState {
  final String groupId;
  final GroupModel group;
  const CreateGroupSuccess({required this.groupId, required this.group});
}

class CreateGroupFailure extends CreateGroupState {
  final String message;
  const CreateGroupFailure(this.message);
}

class CreateGroupNotifier extends Notifier<CreateGroupState> {
  @override
  CreateGroupState build() => const CreateGroupIdle();

  Future<void> createGroup({
    required String groupName,
    required String groupType,
    required String groupIcon,
  }) async {
    final authState = ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) {
      state = const CreateGroupFailure('You must be signed in to create a group.');
      return;
    }

    state = const CreateGroupLoading();

    try {
      final uid = authState.user.uid;
      final name = authState.user.name;

      final group = GroupModel(
        id: '',
        groupName: groupName.trim(),
        groupType: groupType,
        groupIcon: groupIcon,
        createdBy: uid,
        members: [uid],
        memberCount: 1,
        balance: 0.0,
        currency: 'INR',
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final service = ref.read(groupFirestoreServiceProvider);
      final groupId = await service.createGroup(
        group: group,
        creatorName: name,
      );

      final created = GroupModel(
        id: groupId,
        groupName: group.groupName,
        groupType: group.groupType,
        groupIcon: group.groupIcon,
        createdBy: uid,
        members: [uid],
        memberCount: 1,
        balance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      state = CreateGroupSuccess(groupId: groupId, group: created);
    } catch (e) {
      state = CreateGroupFailure('Failed to create group: ${e.toString()}');
    }
  }

  void reset() => state = const CreateGroupIdle();
}

final createGroupProvider =
    NotifierProvider<CreateGroupNotifier, CreateGroupState>(
  CreateGroupNotifier.new,
);

// ─── Group Expenses Stream ────────────────────────────────────────────────

final groupExpensesProvider = StreamProvider.autoDispose
    .family<List<ExpenseModel>, String>((ref, groupId) {
  return ref
      .read(groupFirestoreServiceProvider)
      .watchGroupExpenses(groupId);
});
