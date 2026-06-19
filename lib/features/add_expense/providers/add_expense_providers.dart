import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/group_member_model.dart';
import '../../../models/payer_config.dart';
import '../../../models/split_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bill Tab State
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the full form state for a single bill tab.
class BillTabState {
  final String description;
  final double amount;
  final String category;
  final String notes;
  final DateTime date;
  final String payerType;
  final String singlePayerId;
  final String singlePayerName;
  final Map<String, double> multiPayerAmounts;
  final String splitType;
  final List<String> splitAmongIds;
  final Map<String, double> unequalAmounts;
  final Map<String, int> unequalShares;
  final List<SplitItem> itemWiseSplits;
  final List<String> imageUrls;

  BillTabState({
    this.description = '',
    this.amount = 0.0,
    this.category = 'misc',
    this.notes = '',
    DateTime? date,
    this.payerType = 'single',
    this.singlePayerId = '',
    this.singlePayerName = '',
    this.multiPayerAmounts = const {},
    this.splitType = 'equal',
    this.splitAmongIds = const [],
    this.unequalAmounts = const {},
    this.unequalShares = const {},
    this.itemWiseSplits = const [],
    this.imageUrls = const [],
  }) : date = date ?? DateTime.now();

  BillTabState copyWith({
    String? description,
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
    List<String>? imageUrls,
  }) {
    return BillTabState(
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      payerType: payerType ?? this.payerType,
      singlePayerId: singlePayerId ?? this.singlePayerId,
      singlePayerName: singlePayerName ?? this.singlePayerName,
      multiPayerAmounts: multiPayerAmounts ?? this.multiPayerAmounts,
      splitType: splitType ?? this.splitType,
      splitAmongIds: splitAmongIds ?? this.splitAmongIds,
      unequalAmounts: unequalAmounts ?? this.unequalAmounts,
      unequalShares: unequalShares ?? this.unequalShares,
      itemWiseSplits: itemWiseSplits ?? this.itemWiseSplits,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  bool get isValid {
    if (description.trim().isEmpty) return false;
    if (amount <= 0) return false;
    if (splitAmongIds.isEmpty) return false;
    if (singlePayerId.isEmpty && payerType == 'single') return false;
    if (payerType == 'multi') {
      final total = multiPayerAmounts.values.fold(0.0, (a, b) => a + b);
      if ((total - amount).abs() > 0.01) return false;
    }
    if (splitType == 'unequalAmount') {
      final total = unequalAmounts.values.fold(0.0, (a, b) => a + b);
      if ((total - amount).abs() > 0.01) return false;
    }
    if (splitType == 'itemWise') {
      if (itemWiseSplits.isEmpty) return false;
      final total = itemWiseSplits.fold(0.0, (s, i) => s + i.totalPrice);
      if ((total - amount).abs() > 0.01) return false;
      if (itemWiseSplits.any((i) => i.memberIds.isEmpty)) return false;
    }
    return true;
  }

  PayerConfig get payerConfig {
    if (payerType == 'multi') return MultiPayer(multiPayerAmounts);
    return SinglePayer(userId: singlePayerId, userName: singlePayerName, amount: amount);
  }

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
}



// ─────────────────────────────────────────────────────────────────────────────
// Add Expense Notifier (main form state)
// ─────────────────────────────────────────────────────────────────────────────

class AddExpenseNotifier extends Notifier<BillTabState> {
  @override
  BillTabState build() => BillTabState(date: DateTime.now());

  void updateDescription(String v) => state = state.copyWith(description: v);
  void updateAmount(double v) => state = state.copyWith(amount: v);
  void updateCategory(String v) => state = state.copyWith(category: v);
  void updateNotes(String v) => state = state.copyWith(notes: v);
  void updateDate(DateTime v) => state = state.copyWith(date: v);

  void setSinglePayer(String id, String name) => state = state.copyWith(
        payerType: 'single',
        singlePayerId: id,
        singlePayerName: name,
        multiPayerAmounts: {},
      );

  void setMultiPayer(Map<String, double> amounts) => state = state.copyWith(
        payerType: 'multi',
        singlePayerId: '',
        singlePayerName: '',
        multiPayerAmounts: amounts,
      );

  void setEqualSplit(List<String> memberIds) => state = state.copyWith(
        splitType: 'equal',
        splitAmongIds: memberIds,
        unequalAmounts: {},
        unequalShares: {},
        itemWiseSplits: [],
      );

  void setUnequalByAmount(Map<String, double> amounts) => state = state.copyWith(
        splitType: 'unequalAmount',
        splitAmongIds: amounts.keys.toList(),
        unequalAmounts: amounts,
      );

  void setUnequalByShares(Map<String, int> shares) => state = state.copyWith(
        splitType: 'unequalShares',
        splitAmongIds: shares.keys.toList(),
        unequalShares: shares,
      );

  void setItemWiseSplit(List<SplitItem> items) => state = state.copyWith(
        splitType: 'itemWise',
        itemWiseSplits: items,
      );

  void addImageUrl(String url) =>
      state = state.copyWith(imageUrls: [...state.imageUrls, url]);

  void removeImageUrl(String url) =>
      state = state.copyWith(imageUrls: state.imageUrls.where((u) => u != url).toList());

  void reset() => state = BillTabState(date: DateTime.now());

  BillTabState snapshot() => state;
  void restore(BillTabState saved) => state = saved;
}

final addExpenseProvider =
    NotifierProvider<AddExpenseNotifier, BillTabState>(AddExpenseNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Member Selection Notifier
// ─────────────────────────────────────────────────────────────────────────────

class MemberSelectionNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void setMembers(List<String> ids) => state = List.from(ids);

  void addMember(String id) {
    if (!state.contains(id)) state = [...state, id];
  }

  void removeMember(String id) =>
      state = state.where((m) => m != id).toList();

  void toggle(String id) {
    if (state.contains(id)) {
      removeMember(id);
    } else {
      addMember(id);
    }
  }

  void clearMembers() => state = [];

  bool isSelected(String id) => state.contains(id);
}

final memberSelectionProvider =
    NotifierProvider<MemberSelectionNotifier, List<String>>(
        MemberSelectionNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Bill Tab Notifier (multi-bill)
// ─────────────────────────────────────────────────────────────────────────────

class BillTabsState {
  final List<BillTabState> tabs;
  final int activeIndex;

  const BillTabsState({required this.tabs, this.activeIndex = 0});

  BillTabState get activeTab => tabs[activeIndex];

  BillTabsState copyWith({List<BillTabState>? tabs, int? activeIndex}) {
    return BillTabsState(
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class BillTabsNotifier extends Notifier<BillTabsState> {
  @override
  BillTabsState build() => BillTabsState(tabs: [BillTabState(date: DateTime.now())]);

  void addBill() {
    final newTabs = [...state.tabs, BillTabState(date: DateTime.now())];
    state = state.copyWith(tabs: newTabs, activeIndex: newTabs.length - 1);
  }

  void switchTab(int index) => state = state.copyWith(activeIndex: index);

  void removeBill(int index) {
    if (state.tabs.length <= 1) return;
    final newTabs = [...state.tabs]..removeAt(index);
    final newIndex = index >= newTabs.length ? newTabs.length - 1 : index;
    state = state.copyWith(tabs: newTabs, activeIndex: newIndex);
  }

  void updateActiveTab(BillTabState tab) {
    final newTabs = [...state.tabs];
    newTabs[state.activeIndex] = tab;
    state = state.copyWith(tabs: newTabs);
  }

  bool get allTabsValid => state.tabs.every((t) => t.isValid);
}

final billTabsProvider =
    NotifierProvider<BillTabsNotifier, BillTabsState>(BillTabsNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Group Members Provider (fetches member details for a group)
// ─────────────────────────────────────────────────────────────────────────────

/// Simple in-memory cache of group members for use across the add expense flow.
/// Populated by AddExpensePage when it mounts.
class GroupMembersNotifier extends Notifier<List<GroupMemberModel>> {
  @override
  List<GroupMemberModel> build() => [];

  void setMembers(List<GroupMemberModel> members) => state = members;

  GroupMemberModel? findById(String id) {
    try {
      return state.firstWhere((m) => m.userId == id);
    } catch (_) {
      return null;
    }
  }
}

final groupMembersProvider =
    NotifierProvider<GroupMembersNotifier, List<GroupMemberModel>>(
        GroupMembersNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Custom Category Notifier (local-only in Phase 1)
// ─────────────────────────────────────────────────────────────────────────────

class CustomCategoriesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void add(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !state.contains(trimmed)) {
      state = [...state, trimmed];
    }
  }
}

final customCategoriesProvider =
    NotifierProvider<CustomCategoriesNotifier, List<String>>(
        CustomCategoriesNotifier.new);
