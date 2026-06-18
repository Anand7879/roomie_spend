/// Data model representing statistics shown on the Dashboard.
class DashboardStats {
  final double todaySpending;
  final double monthlySpending;
  final int activeGroups;
  final int pendingSettlements;
  final double youOwe;
  final double youGet;

  DashboardStats({
    required this.todaySpending,
    required this.monthlySpending,
    required this.activeGroups,
    required this.pendingSettlements,
    required this.youOwe,
    required this.youGet,
  });

  double get netBalance => youGet - youOwe;

  DashboardStats copyWith({
    double? todaySpending,
    double? monthlySpending,
    int? activeGroups,
    int? pendingSettlements,
    double? youOwe,
    double? youGet,
  }) {
    return DashboardStats(
      todaySpending: todaySpending ?? this.todaySpending,
      monthlySpending: monthlySpending ?? this.monthlySpending,
      activeGroups: activeGroups ?? this.activeGroups,
      pendingSettlements: pendingSettlements ?? this.pendingSettlements,
      youOwe: youOwe ?? this.youOwe,
      youGet: youGet ?? this.youGet,
    );
  }
}
