import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stats_model.dart';
import 'group_provider.dart';

/// Notifier that manages statistics displayed on the Dashboard.
/// Calculates stats dynamically from real Firestore data.
class StatsNotifier extends Notifier<DashboardStats> {
  @override
  DashboardStats build() {
    // Watch groupProvider to recalculate stats when groups change
    final groupsList = ref.watch(groupProvider);

    double owe = 0.0;
    double get = 0.0;
    int pending = 0;

    // Calculate from real group data
    for (final g in groupsList) {
      if (g.balance < 0) {
        owe += g.balance.abs();
        pending++;
      } else if (g.balance > 0) {
        get += g.balance;
        pending++;
      }
    }

    return DashboardStats(
      todaySpending: 0.0, // Will be updated when expenses are added
      monthlySpending: 0.0, // Will be updated when expenses are added
      activeGroups: groupsList.length,
      pendingSettlements: pending,
      youOwe: owe,
      youGet: get,
    );
  }

  /// Record a spending amount
  void addSpend(double amount) {
    state = state.copyWith(
      todaySpending: state.todaySpending + amount,
      monthlySpending: state.monthlySpending + amount,
    );
  }

  /// Decrease pending settlements count
  void settleOne() {
    if (state.pendingSettlements > 0) {
      state = state.copyWith(
        pendingSettlements: state.pendingSettlements - 1,
      );
    }
  }
}

/// Riverpod provider for dashboard statistics.
final statsProvider = NotifierProvider<StatsNotifier, DashboardStats>(
  StatsNotifier.new,
);
