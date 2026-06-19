import 'package:cloud_firestore/cloud_firestore.dart';
import 'expense_model.dart';
import 'payer_config.dart';
import 'split_config.dart';

/// Extended expense model supporting multi-payer, unequal splits,
/// item-wise splits, multi-bill support, and image attachments.
///
/// Backward-compatible with [ExpenseModel] — legacy documents are read gracefully.
/// Validates: Requirement 17.2
class EnhancedExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String category;
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  // ─── Payer Fields ─────────────────────────────────────────────────────────
  /// 'single' or 'multi'
  final String payerType;
  /// UID of the single payer (when payerType == 'single')
  final String singlePayerId;
  /// Display name of the single payer
  final String singlePayerName;
  /// Map of userId → amount paid (when payerType == 'multi')
  final Map<String, double> multiPayerAmounts;

  // ─── Split Fields ─────────────────────────────────────────────────────────
  /// 'equal', 'unequalAmount', 'unequalShares', or 'itemWise'
  final String splitType;
  /// Member IDs included in the split
  final List<String> splitAmongIds;
  /// Map of userId → amount owed (for unequalAmount splits)
  final Map<String, double> unequalAmounts;
  /// Map of userId → share count (for unequalShares splits)
  final Map<String, int> unequalShares;
  /// List of split items (for itemWise splits)
  final List<SplitItem> itemWiseSplits;

  // ─── Multi-Bill Fields ────────────────────────────────────────────────────
  /// Bill number within a multi-bill group (1-indexed, null for single bills)
  final int? billNumber;
  /// Parent expense ID linking bills in a multi-bill session
  final String? parentExpenseId;

  // ─── Image Fields ─────────────────────────────────────────────────────────
  /// Firebase Storage download URLs for attached images
  final List<String> imageUrls;

  const EnhancedExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    this.category = 'General',
    this.notes = '',
    required this.date,
    required this.createdAt,
    this.payerType = 'single',
    this.singlePayerId = '',
    this.singlePayerName = '',
    this.multiPayerAmounts = const {},
    this.splitType = 'equal',
    this.splitAmongIds = const [],
    this.unequalAmounts = const {},
    this.unequalShares = const {},
    this.itemWiseSplits = const [],
    this.billNumber,
    this.parentExpenseId,
    this.imageUrls = const [],
  });

  /// Creates an [EnhancedExpenseModel] from a legacy [ExpenseModel].
  factory EnhancedExpenseModel.fromLegacy(ExpenseModel legacy) {
    return EnhancedExpenseModel(
      id: legacy.id,
      groupId: legacy.groupId,
      title: legacy.title,
      amount: legacy.amount,
      category: legacy.category,
      notes: legacy.notes,
      date: legacy.date,
      createdAt: legacy.createdAt,
      payerType: 'single',
      singlePayerId: legacy.paidBy,
      singlePayerName: '',
      splitType: 'equal',
      splitAmongIds: legacy.splitAmong,
    );
  }

  /// Backward-compatible factory — reads both legacy and enhanced Firestore documents.
  factory EnhancedExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    // ── Payer ──
    final payerType = map['payerType'] as String? ?? 'single';
    final multiPayerRaw = map['multiPayerAmounts'] as Map?;
    final multiPayerAmounts = multiPayerRaw != null
        ? Map<String, double>.from(
            multiPayerRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
          )
        : <String, double>{};

    // ── Split ──
    final splitType = map['splitType'] as String? ?? 'equal';

    final unequalAmountsRaw = map['unequalAmounts'] as Map?;
    final unequalAmounts = unequalAmountsRaw != null
        ? Map<String, double>.from(
            unequalAmountsRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
          )
        : <String, double>{};

    final unequalSharesRaw = map['unequalShares'] as Map?;
    final unequalShares = unequalSharesRaw != null
        ? Map<String, int>.from(
            unequalSharesRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
          )
        : <String, int>{};

    final itemWiseRaw = map['itemWiseSplits'] as List?;
    final itemWiseSplits = itemWiseRaw != null
        ? itemWiseRaw.map((i) => SplitItem.fromMap(i as Map<String, dynamic>)).toList()
        : <SplitItem>[];

    // ── Split among ── (legacy uses 'splitAmong', new uses 'splitAmongIds')
    final splitAmongIds = List<String>.from(
      map['splitAmongIds'] as List? ?? map['splitAmong'] as List? ?? [],
    );

    return EnhancedExpenseModel(
      id: docId,
      groupId: map['groupId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'General',
      notes: map['notes'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      payerType: payerType,
      singlePayerId: map['singlePayerId'] as String? ?? map['paidBy'] as String? ?? '',
      singlePayerName: map['singlePayerName'] as String? ?? '',
      multiPayerAmounts: multiPayerAmounts,
      splitType: splitType,
      splitAmongIds: splitAmongIds,
      unequalAmounts: unequalAmounts,
      unequalShares: unequalShares,
      itemWiseSplits: itemWiseSplits,
      billNumber: map['billNumber'] as int?,
      parentExpenseId: map['parentExpenseId'] as String?,
      imageUrls: List<String>.from(map['imageUrls'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'category': category,
      'notes': notes,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      // Payer
      'payerType': payerType,
      'singlePayerId': singlePayerId,
      'singlePayerName': singlePayerName,
      'multiPayerAmounts': multiPayerAmounts,
      // Legacy compat field
      'paidBy': singlePayerId,
      // Split
      'splitType': splitType,
      'splitAmongIds': splitAmongIds,
      // Legacy compat field
      'splitAmong': splitAmongIds,
      'unequalAmounts': unequalAmounts,
      'unequalShares': unequalShares,
      'itemWiseSplits': itemWiseSplits.map((i) => i.toMap()).toList(),
      // Multi-bill
      'billNumber': billNumber,
      'parentExpenseId': parentExpenseId,
      // Images
      'imageUrls': imageUrls,
    };
  }

  /// Derives a [PayerConfig] from the stored fields.
  PayerConfig get payerConfig {
    if (payerType == 'multi') {
      return MultiPayer(multiPayerAmounts);
    }
    return SinglePayer(userId: singlePayerId, userName: singlePayerName, amount: amount);
  }

  /// Derives a [SplitConfig] from the stored fields.
  SplitConfig get splitConfig {
    switch (splitType) {
      case 'unequalAmount':
        return UnequalSplitByAmount(unequalAmounts);
      case 'unequalShares':
        return UnequalSplitByShares(unequalShares);
      case 'itemWise':
        return ItemWiseSplit(itemWiseSplits);
      default:
        return EqualSplit(splitAmongIds);
    }
  }

  /// Display label for the payer field in the UI.
  String get payerDisplayName {
    if (payerType == 'multi') return 'Multiple Payers';
    return singlePayerName.isNotEmpty ? singlePayerName : singlePayerId;
  }

  EnhancedExpenseModel copyWith({
    String? id,
    String? groupId,
    String? title,
    double? amount,
    String? category,
    String? notes,
    DateTime? date,
    String? payerType,
    String? singlePayerId,
    String? singlePayerName,
    Map<String, double>? multiPayerAmounts,
    String? splitType,
    List<String>? splitAmongIds,
    Map<String, double>? unequalAmounts,
    Map<String, int>? unequalShares,
    List<SplitItem>? itemWiseSplits,
    int? billNumber,
    String? parentExpenseId,
    List<String>? imageUrls,
  }) {
    return EnhancedExpenseModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt,
      payerType: payerType ?? this.payerType,
      singlePayerId: singlePayerId ?? this.singlePayerId,
      singlePayerName: singlePayerName ?? this.singlePayerName,
      multiPayerAmounts: multiPayerAmounts ?? this.multiPayerAmounts,
      splitType: splitType ?? this.splitType,
      splitAmongIds: splitAmongIds ?? this.splitAmongIds,
      unequalAmounts: unequalAmounts ?? this.unequalAmounts,
      unequalShares: unequalShares ?? this.unequalShares,
      itemWiseSplits: itemWiseSplits ?? this.itemWiseSplits,
      billNumber: billNumber ?? this.billNumber,
      parentExpenseId: parentExpenseId ?? this.parentExpenseId,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}
