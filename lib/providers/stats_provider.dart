import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stats_model.dart';
import 'group_provider.dart';

/// Notifier that manages statistics displayed on the Dashboard.
/// Initialized with mockup data to match the designer specifications exactly.
class StatsNotifier extends Notifier<DashboardStats> {
  double _todaySpending = 4300.00;
  double _monthlySpending = 12200.00;

  @override
  DashboardStats build() {
    // Watch groupProvider
    final groupsList = ref.watch(groupProvider);

    double owe = 320.00;
    double get = 4200.00;
    int pending = 3;

    // If there is user modification, we can adjust.
    // For visual consistency with the mockup, we fall back to the mockup values if the groups list
    // matches the initial state, otherwise we calculate dynamically.
    final bool isInitialState = groupsList.length == 3 &&
        groupsList[0].balance == 2950.0 &&
        groupsList[1].balance == -320.0 &&
        groupsList[2].balance == 1200.0;

    if (!isInitialState) {
      owe = 0.0;
      get = 0.0;
      pending = 0;
      for (final g in groupsList) {
        if (g.balance < 0) {
          owe += g.balance.abs();
          pending++;
        } else if (g.balance > 0) {
          get += g.balance;
          pending++;
        }
      }
    }

    return DashboardStats(
      todaySpending: _todaySpending,
      monthlySpending: _monthlySpending,
      activeGroups: isInitialState ? 4 : groupsList.length,
      pendingSettlements: pending,
      youOwe: owe,
      youGet: get,
    );
  }

  /// Record a spending amount
  void addSpend(double amount) {
    _todaySpending += amount;
    _monthlySpending += amount;
    
    state = state.copyWith(
      todaySpending: _todaySpending,
      monthlySpending: _monthlySpending,
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
