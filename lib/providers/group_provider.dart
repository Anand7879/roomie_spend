import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';

/// Notifier that manages the list of groups.
/// Initialized with mockup data to match the designer specifications.
class GroupNotifier extends Notifier<List<GroupModel>> {
  @override
  List<GroupModel> build() {
    return [
      GroupModel(
        id: 'g1',
        name: 'Flatmates Group',
        imageUrl: '🏠',
        memberCount: 3,
        lastActivity: 'You imported Wifi Bill',
        balance: 2950.00, // Gets ₹2950
      ),
      GroupModel(
        id: 'g2',
        name: 'Weekend Chill',
        imageUrl: '🌴',
        memberCount: 5,
        lastActivity: 'You scanned Diner Receipt',
        balance: -320.00, // Owes ₹320
      ),
      GroupModel(
        id: 'g3',
        name: 'Office Team',
        imageUrl: '💼',
        memberCount: 8,
        lastActivity: 'Monthly Lunch',
        balance: 1200.00, // Gets ₹1200
      ),
    ];
  }

  /// Add a new group to the state
  void addGroup(GroupModel group) {
    state = [...state, group];
  }

  /// Update the last activity of a group
  void updateLastActivity(String groupId, String activity, double balanceChange) {
    state = [
      for (final g in state)
        if (g.id == groupId)
          GroupModel(
            id: g.id,
            name: g.name,
            imageUrl: g.imageUrl,
            memberCount: g.memberCount,
            lastActivity: activity,
            balance: g.balance + balanceChange,
          )
        else
          g
    ];
  }
}

/// Riverpod provider for the list of roommate groups.
final groupProvider = NotifierProvider<GroupNotifier, List<GroupModel>>(
  GroupNotifier.new,
);
