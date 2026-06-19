/// Split configuration sealed class hierarchy for expense splitting
///
/// Supports four split types:
/// - EqualSplit: Split equally among members
/// - UnequalSplitByAmount: Split with specific amounts per member
/// - UnequalSplitByShares: Split proportionally based on shares
/// - ItemWiseSplit: Split based on individual items consumed

sealed class SplitConfig {
  const SplitConfig();

  /// Calculate the amount each member owes for this split configuration
  Map<String, double> calculateAmounts(double total);

  /// Validate that this split configuration is valid for the given total amount
  bool isValid(double total);

  /// Convert split configuration to Firestore map
  Map<String, dynamic> toMap();

  /// Create split configuration from Firestore map
  static SplitConfig fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    
    switch (type) {
      case 'equal':
        return EqualSplit.fromMap(map);
      case 'unequalAmount':
        return UnequalSplitByAmount.fromMap(map);
      case 'unequalShares':
        return UnequalSplitByShares.fromMap(map);
      case 'itemWise':
        return ItemWiseSplit.fromMap(map);
      default:
        throw ArgumentError('Unknown split type: $type');
    }
  }
}

/// Equal split among selected members
///
/// **Validates: Requirements 11.1, 11.3**
class EqualSplit extends SplitConfig {
  final List<String> memberIds;

  const EqualSplit(this.memberIds);

  @override
  Map<String, double> calculateAmounts(double total) {
    if (memberIds.isEmpty) {
      return {};
    }

    final share = total / memberIds.length;
    final result = <String, double>{};
    
    // Assign equal shares to all members
    for (var id in memberIds) {
      result[id] = share;
    }

    // Handle rounding: adjust last member's share to ensure sum equals total
    // **Validates: Requirements 11.5, 11.6**
    final sum = result.values.fold(0.0, (a, b) => a + b);
    final difference = total - sum;
    
    if (difference.abs() > 0.00001 && memberIds.isNotEmpty) {
      result[memberIds.last] = result[memberIds.last]! + difference;
    }

    return result;
  }

  @override
  bool isValid(double total) {
    return memberIds.isNotEmpty && total > 0;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'equal',
      'memberIds': memberIds,
    };
  }

  factory EqualSplit.fromMap(Map<String, dynamic> map) {
    return EqualSplit(
      List<String>.from(map['memberIds'] as List? ?? []),
    );
  }
}

/// Unequal split with specific amounts per member
///
/// **Validates: Requirements 12.1**
class UnequalSplitByAmount extends SplitConfig {
  final Map<String, double> amounts;

  const UnequalSplitByAmount(this.amounts);

  @override
  Map<String, double> calculateAmounts(double total) {
    // Amounts are already specified, just return them
    return Map<String, double>.from(amounts);
  }

  @override
  bool isValid(double total) {
    if (amounts.isEmpty) return false;
    
    final sum = amounts.values.fold(0.0, (a, b) => a + b);
    
    // Check if sum equals total (within floating point tolerance)
    // **Validates: Requirements 12.5, 12.6**
    return (sum - total).abs() < 0.01;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'unequalAmount',
      'amounts': amounts,
    };
  }

  factory UnequalSplitByAmount.fromMap(Map<String, dynamic> map) {
    final amountsMap = map['amounts'] as Map<String, dynamic>? ?? {};
    return UnequalSplitByAmount(
      amountsMap.map((key, value) => MapEntry(key, (value as num).toDouble())),
    );
  }
}

/// Unequal split with proportional shares
///
/// **Validates: Requirements 13.1**
class UnequalSplitByShares extends SplitConfig {
  final Map<String, int> shares;

  const UnequalSplitByShares(this.shares);

  @override
  Map<String, double> calculateAmounts(double total) {
    if (shares.isEmpty) {
      return {};
    }

    final totalShares = shares.values.fold(0, (a, b) => a + b);
    
    if (totalShares == 0) {
      return {};
    }

    // Calculate proportional amount for each member
    // **Validates: Requirements 13.2**
    // Formula: memberAmount = (memberShare / totalShares) × expenseAmount
    final result = <String, double>{};
    final membersList = shares.keys.toList();
    
    for (var i = 0; i < membersList.length; i++) {
      final id = membersList[i];
      final share = shares[id]!;
      result[id] = (share / totalShares) * total;
    }

    // Handle rounding: adjust last member's share to ensure sum equals total
    final sum = result.values.fold(0.0, (a, b) => a + b);
    final difference = total - sum;
    
    if (difference.abs() > 0.00001 && membersList.isNotEmpty) {
      final lastId = membersList.last;
      result[lastId] = result[lastId]! + difference;
    }

    return result;
  }

  @override
  bool isValid(double total) {
    if (shares.isEmpty) return false;
    
    final totalShares = shares.values.fold(0, (a, b) => a + b);
    return totalShares > 0 && total > 0;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'unequalShares',
      'shares': shares,
    };
  }

  factory UnequalSplitByShares.fromMap(Map<String, dynamic> map) {
    final sharesMap = map['shares'] as Map<String, dynamic>? ?? {};
    return UnequalSplitByShares(
      sharesMap.map((key, value) => MapEntry(key, value as int)),
    );
  }
}

/// Item-wise split based on individual items consumed
///
/// **Validates: Requirements 14.1**
class ItemWiseSplit extends SplitConfig {
  final List<SplitItem> items;

  const ItemWiseSplit(this.items);

  @override
  Map<String, double> calculateAmounts(double total) {
    final result = <String, double>{};

    // Calculate amount per member based on items they're assigned to
    for (final item in items) {
      if (item.memberIds.isEmpty) continue;
      
      final sharePerPerson = item.totalPrice / item.memberIds.length;
      
      for (final memberId in item.memberIds) {
        result[memberId] = (result[memberId] ?? 0.0) + sharePerPerson;
      }
    }

    return result;
  }

  @override
  bool isValid(double total) {
    if (items.isEmpty) return false;
    
    // Check that all items have at least one member assigned
    if (items.any((item) => item.memberIds.isEmpty)) {
      return false;
    }

    // Check that sum of item totals equals expense amount
    // **Validates: Requirements 14.10, 14.11**
    final itemsTotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    return (itemsTotal - total).abs() < 0.01;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'itemWise',
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory ItemWiseSplit.fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List? ?? [];
    return ItemWiseSplit(
      itemsList.map((item) => SplitItem.fromMap(item as Map<String, dynamic>)).toList(),
    );
  }
}

/// Represents a single item in an item-wise split
///
/// **Validates: Requirements 14.1**
class SplitItem {
  final String description;
  final int quantity;
  final double pricePerUnit;
  final List<String> memberIds;

  const SplitItem({
    required this.description,
    required this.quantity,
    required this.pricePerUnit,
    required this.memberIds,
  });

  /// Calculate total price for this item
  double get totalPrice => quantity * pricePerUnit;

  /// Convert item to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'memberIds': memberIds,
    };
  }

  /// Create item from Firestore map
  factory SplitItem.fromMap(Map<String, dynamic> map) {
    return SplitItem(
      description: map['description'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 1,
      pricePerUnit: (map['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
    );
  }

  /// Create a copy of this item with optional field updates
  SplitItem copyWith({
    String? description,
    int? quantity,
    double? pricePerUnit,
    List<String>? memberIds,
  }) {
    return SplitItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      memberIds: memberIds ?? this.memberIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SplitItem &&
        other.description == description &&
        other.quantity == quantity &&
        other.pricePerUnit == pricePerUnit &&
        _listEquals(other.memberIds, memberIds);
  }

  @override
  int get hashCode {
    return description.hashCode ^
        quantity.hashCode ^
        pricePerUnit.hashCode ^
        memberIds.hashCode;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
