/// Sealed class hierarchy for payer configuration in expenses.
/// 
/// Supports both single-payer and multi-payer scenarios as specified in
/// Requirements 9.5, 9.6, 10.1, 10.6.
sealed class PayerConfig {
  const PayerConfig();

  /// Validates if the payer configuration is valid for the given expense amount.
  /// 
  /// For [SinglePayer]: always returns true as long as the payer is set.
  /// For [MultiPayer]: validates that the sum of payer amounts equals the expense amount.
  bool isValid(double expenseAmount);

  /// Converts the payer configuration to a map for Firestore serialization.
  Map<String, dynamic> toMap();

  /// Creates a [PayerConfig] instance from a Firestore map.
  /// 
  /// Determines the payer type from the map structure and returns the
  /// appropriate subclass ([SinglePayer] or [MultiPayer]).
  factory PayerConfig.fromMap(Map<String, dynamic> map) {
    final payerType = map['payerType'] as String?;
    
    if (payerType == 'multi') {
      final payerAmounts = Map<String, double>.from(
        (map['multiPayerAmounts'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ) ?? {},
      );
      return MultiPayer(payerAmounts);
    } else {
      // Default to single payer
      return SinglePayer(
        userId: map['singlePayerId'] as String? ?? '',
        userName: map['singlePayerName'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      );
    }
  }
}

/// Single payer configuration where one member pays the entire expense amount.
/// 
/// Validates: Requirements 9.5, 9.6
class SinglePayer extends PayerConfig {
  /// User ID of the member who paid for the expense.
  final String userId;
  
  /// Display name of the member who paid for the expense.
  final String userName;
  
  /// Amount paid by this member (always equal to the expense amount).
  final double amount;

  const SinglePayer({
    required this.userId,
    required this.userName,
    required this.amount,
  });

  @override
  bool isValid(double expenseAmount) {
    // Single payer is valid if userId is set and amount matches expense amount
    // Using a small epsilon for floating point comparison
    return userId.isNotEmpty && (amount - expenseAmount).abs() < 0.01;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'payerType': 'single',
      'singlePayerId': userId,
      'singlePayerName': userName,
      'multiPayerAmounts': null,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SinglePayer &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          userName == other.userName &&
          amount == other.amount;

  @override
  int get hashCode => Object.hash(userId, userName, amount);

  @override
  String toString() => 'SinglePayer(userId: $userId, userName: $userName, amount: $amount)';
}

/// Multi-payer configuration where multiple members pay for the expense.
/// 
/// Validates: Requirements 10.1, 10.6
class MultiPayer extends PayerConfig {
  /// Map of user IDs to the amount each payer contributed.
  /// Key: userId, Value: amount paid by that user.
  final Map<String, double> payerAmounts;

  const MultiPayer(this.payerAmounts);

  /// Calculates the total amount paid by all payers.
  double get total => payerAmounts.values.fold(0.0, (a, b) => a + b);

  /// Calculates the remaining amount to be allocated.
  /// 
  /// Returns the difference between the expense amount and the sum of all
  /// payer amounts. This is used for real-time validation in the UI.
  /// 
  /// Validates: Requirement 10.4
  double getRemaining(double expenseAmount) {
    return expenseAmount - total;
  }

  @override
  bool isValid(double expenseAmount) {
    // Multi-payer is valid when:
    // 1. At least one payer is present
    // 2. Sum of payer amounts equals the expense amount (within epsilon)
    // Validates: Requirements 10.5, 10.6
    if (payerAmounts.isEmpty) return false;
    return (total - expenseAmount).abs() < 0.01;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'payerType': 'multi',
      'singlePayerId': null,
      'singlePayerName': null,
      'multiPayerAmounts': payerAmounts,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiPayer &&
          runtimeType == other.runtimeType &&
          _mapEquals(payerAmounts, other.payerAmounts);

  @override
  int get hashCode {
    int hash = 0;
    for (final entry in payerAmounts.entries) {
      hash ^= Object.hash(entry.key, entry.value);
    }
    return hash;
  }

  @override
  String toString() => 'MultiPayer(payerAmounts: $payerAmounts, total: $total)';

  /// Helper method to compare two maps for equality.
  bool _mapEquals(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
