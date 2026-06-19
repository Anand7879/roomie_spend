import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';
import 'group_detail_provider.dart';
import 'auth_provider.dart';

/// Provider that syncs with Firestore groups for backward compatibility.
class GroupNotifier extends Notifier<List<GroupModel>> {
  @override
  List<GroupModel> build() {
    // Watch the real Firestore stream
    final authState = ref.watch(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return []; // Return empty list when not authenticated
    }

    // Asynchronously sync Firestore data into the local state
    ref.listen<AsyncValue<List<GroupModel>>>(userGroupsProvider, (_, next) {
      next.whenData((groups) {
        state = groups;
      });
    });

    // Immediately apply current Firestore value if already loaded
    final firestoreAsync = ref.read(userGroupsProvider);
    return firestoreAsync.when(
      data: (groups) => groups,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// Add a newly created group locally for instant UI feedback.
  void addGroup(GroupModel group) {
    state = [group, ...state];
  }

  /// Legacy method used by home_screen dialogs.
  void updateLastActivity(
      String groupId, String activity, double balanceChange) {
    state = [
      for (final g in state)
        if (g.id == groupId)
          GroupModel(
            id: g.id,
            groupName: g.groupName,
            groupType: g.groupType,
            groupIcon: g.groupIcon,
            createdBy: g.createdBy,
            members: g.members,
            memberCount: g.memberCount,
            balance: g.balance + balanceChange,
            createdAt: g.createdAt,
            updatedAt: DateTime.now(),
          )
        else
          g,
    ];
  }
}

final groupProvider = NotifierProvider<GroupNotifier, List<GroupModel>>(
  GroupNotifier.new,
);
