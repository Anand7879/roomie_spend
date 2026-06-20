import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/expense_category.dart';
import '../../models/enhanced_expense_model.dart';
import '../../models/group_member_model.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';

import '../../services/expense_firestore_service.dart';
import 'providers/add_expense_providers.dart';
import 'sheets/member_selection_sheet.dart';
import 'sheets/category_sheet.dart';
import 'sheets/paid_by_sheet.dart';
import 'sheets/split_sheet.dart';
import 'sheets/item_wise_split_sheet.dart';
import 'widgets/date_picker_card.dart';
import 'widgets/image_attachment_section.dart';

/// Full-screen Add Expense page.
/// Validates: Requirements 1.1, 2.1–2.7, all sub-requirements
class AddExpensePage extends ConsumerStatefulWidget {
  final GroupModel group;

  const AddExpensePage({super.key, required this.group});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _expenseService = ExpenseFirestoreService();
  List<File> _localImages = [];
  bool _saving = false;

  // ─── Member Details (cached) ───────────────────────────────────────────
  List<GroupMemberModel> _allMembers = [];

  @override
  void initState() {
    super.initState();
    // Reset providers for a fresh session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addExpenseProvider.notifier).reset();
      ref.read(memberSelectionProvider.notifier).clearMembers();
      _buildMemberList();
    });
  }

  void _buildMemberList() {
    final group = widget.group;
    // Build a simple member list from group.members UIDs
    // (names resolved if available from groupMembersProvider)
    final cached = ref.read(groupMembersProvider);
    if (cached.isNotEmpty) {
      _allMembers = cached;
    } else {
      // Fallback: create placeholder members from UIDs
      _allMembers = group.members.map((uid) {
        final found = cached.firstWhere(
          (m) => m.userId == uid,
          orElse: () => GroupMemberModel(
            id: uid,
            groupId: group.id,
            userId: uid,
            userName: 'Member',
            userAvatar: '👤',
            userPhone: '',
            joinedAt: DateTime.now(),
          ),
        );
        return found;
      }).toList();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    _notesCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Derived state ────────────────────────────────────────────────────
  bool get _canSave {
    final form = ref.read(addExpenseProvider);
    final members = ref.read(memberSelectionProvider);
    if (_descCtrl.text.trim().isEmpty) return false;
    final amt = double.tryParse(_amtCtrl.text) ?? 0.0;
    if (amt <= 0) return false;
    if (members.isEmpty) return false;
    if (form.singlePayerId.isEmpty && form.payerType == 'single') return false;
    return true;
  }

  // ─── Save ─────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;
    final authState = ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) return;

    final amount = double.tryParse(_amtCtrl.text.trim()) ?? 0.0;
    final form = ref.read(addExpenseProvider);
    final selectedMemberIds = ref.read(memberSelectionProvider);

    final expense = EnhancedExpenseModel(
      id: '',
      groupId: widget.group.id,
      title: _descCtrl.text.trim(),
      amount: amount,
      category: form.category,
      notes: _notesCtrl.text.trim(),
      date: form.date,
      createdAt: DateTime.now(),
      payerType: form.payerType,
      singlePayerId: form.singlePayerId,
      singlePayerName: form.singlePayerName,
      multiPayerAmounts: form.multiPayerAmounts,
      splitType: form.splitType,
      splitAmongIds: selectedMemberIds,
      unequalAmounts: form.unequalAmounts,
      unequalShares: form.unequalShares,
      itemWiseSplits: form.itemWiseSplits,
    );

    setState(() => _saving = true);

    try {
      await _expenseService.saveExpense(
        groupId: widget.group.id,
        expense: expense,
        addedByName: authState.user.name,
        groupName: widget.group.groupName,
        addedByUid: authState.user.uid,
        imageFiles: _localImages,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Expense added!',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ─── Sheets ───────────────────────────────────────────────────────────
  void _openMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemberSelectionSheet(allMembers: _allMembers),
    );
  }

  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CategorySheet(),
    );
  }

  void _openPaidBySheet() {
    final selectedIds = ref.read(memberSelectionProvider);
    final selectedMembers =
        _allMembers.where((m) => selectedIds.contains(m.userId)).toList();
    final amount = double.tryParse(_amtCtrl.text) ?? 0.0;

    if (selectedMembers.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add members and amount first'),
          backgroundColor: AppTheme.primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaidBySheet(
        selectedMembers: selectedMembers,
        expenseAmount: amount,
      ),
    );
  }

  void _openSplitSheet(String type) {
    final selectedIds = ref.read(memberSelectionProvider);
    final selectedMembers =
        _allMembers.where((m) => selectedIds.contains(m.userId)).toList();
    final amount = double.tryParse(_amtCtrl.text) ?? 0.0;

    if (selectedMembers.isEmpty) return;

    if (type == 'itemWise') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ItemWiseSplitSheet(
          selectedMembers: selectedMembers,
          expenseAmount: amount,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SplitSheet(
          selectedMembers: selectedMembers,
          expenseAmount: amount,
        ),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final form = ref.watch(addExpenseProvider);
    final selectedMemberIds = ref.watch(memberSelectionProvider);
    final selectedMembers =
        _allMembers.where((m) => selectedMemberIds.contains(m.userId)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Member avatar row ───────────────────────────────────
                _MemberAvatarRow(
                  selectedMembers: selectedMembers,
                  onAddTap: _openMemberSheet,
                  onRemove: (id) =>
                      ref.read(memberSelectionProvider.notifier).removeMember(id),
                ),

                // ── Bill tabs row ──────────────────────────────────────
                const _BillTabsRow(),

                // ── Partner logos ───────────────────────────────────────
                _PartnerLogosRow(),

                // ── Main form card ──────────────────────────────────────
                _FormCard(
                  descCtrl: _descCtrl,
                  amtCtrl: _amtCtrl,
                  notesCtrl: _notesCtrl,
                  form: form,
                  onCategoryTap: _openCategorySheet,
                  onPaidByTap: _openPaidBySheet,
                  onAmountChanged: () => setState(() {}),
                ),

                // ── Split options ───────────────────────────────────────
                if (selectedMemberIds.isNotEmpty) ...[
                  _SplitOptionsRow(
                    currentSplit: form.splitType,
                    onEqualTap: () {
                      ref
                          .read(addExpenseProvider.notifier)
                          .setEqualSplit(selectedMemberIds);
                    },
                    onUnequalTap: () => _openSplitSheet('unequal'),
                    onItemWiseTap: () => _openSplitSheet('itemWise'),
                  ),
                ],

                // ── Equal split preview ─────────────────────────────────
                if (form.splitType == 'equal') ...[
                  _EqualSplitPreview(
                    allMembers: _allMembers,
                    selectedIds: selectedMemberIds,
                    amount: double.tryParse(_amtCtrl.text) ?? 0.0,
                  ),
                ],

                // ── Date, Image, Scan Bill Row ─────────────────────────
                _BottomActionsRow(
                  images: _localImages,
                  onImagesChanged: (imgs) => setState(() => _localImages = imgs),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _SaveBar(
        canSave: _canSave && !_saving,
        saving: _saving,
        onSave: _save,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Add Expense',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.room_preferences_rounded, color: Color(0xFFD97706), size: 13),
              const SizedBox(width: 4),
              Text(
                widget.group.groupName,
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member Avatar Row
// ─────────────────────────────────────────────────────────────────────────────
class _MemberAvatarRow extends StatelessWidget {
  final List<GroupMemberModel> selectedMembers;
  final VoidCallback onAddTap;
  final ValueChanged<String> onRemove;

  const _MemberAvatarRow({
    required this.selectedMembers,
    required this.onAddTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Add friends button
            GestureDetector(
              onTap: onAddTap,
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 6),
                  const Text('Add Friends',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Selected members
            ...selectedMembers.map((m) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _AvatarChip(
                      member: m, onRemove: () => onRemove(m.userId)),
                )),
          ],
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  final GroupMemberModel member;
  final VoidCallback onRemove;

  const _AvatarChip({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: Center(
                child: Text(
                  member.userAvatar.isNotEmpty ? member.userAvatar : '👤',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      color: Colors.black, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          member.userName.split(' ').first,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Partner Logos Row
// ─────────────────────────────────────────────────────────────────────────────
class _PartnerLogosRow extends StatelessWidget {
  final _logos = const [
    ('P', 'PhonePe', Color(0xFF5F259F), Colors.white),
    ('G', 'GPay', Color(0xFFFFFFFF), Color(0xFF4285F4)),
    ('Pay', 'Paytm', Color(0xFF00B9F5), Colors.white),
    ('U', 'Uber', Color(0xFF000000), Colors.white),
    ('S', 'Swiggy', Color(0xFFFC8019), Colors.white),
    ('Z', 'Zomato', Color(0xFFE23744), Colors.white),
    ('Zp', 'Zepto', Color(0xFF4E1687), Colors.white),
    ('B', 'Blinkit', Color(0xFFFFD200), Colors.black),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _logos
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: l.$3,
                                shape: BoxShape.circle,
                                border: l.$2 == 'GPay'
                                    ? Border.all(color: const Color(0xFFE2E8F0), width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  l.$1,
                                  style: TextStyle(
                                    color: l.$4,
                                    fontSize: l.$1.length > 1 ? 11 : 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(l.$2,
                                style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Container(
                    height: 1,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    height: 1,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Form Card
// ─────────────────────────────────────────────────────────────────────────────
class _GridFormCard extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  const _GridFormCard({
    required this.label,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

class _FormCard extends StatelessWidget {
  final TextEditingController descCtrl;
  final TextEditingController amtCtrl;
  final TextEditingController notesCtrl;
  final BillTabState form;
  final VoidCallback onCategoryTap;
  final VoidCallback onPaidByTap;
  final VoidCallback onAmountChanged;

  const _FormCard({
    required this.descCtrl,
    required this.amtCtrl,
    required this.notesCtrl,
    required this.form,
    required this.onCategoryTap,
    required this.onPaidByTap,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final category = ExpenseCategory.fromString(form.category);
    final categoryLabel = category == ExpenseCategory.misc &&
            !ExpenseCategory.values.any((c) => c.name == form.category)
        ? form.category
        : category.label;

    final payerLabel = form.payerType == 'multi'
        ? 'Multiple Payers'
        : form.singlePayerName.isNotEmpty
            ? form.singlePayerName
            : 'Select Payer';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GridFormCard(
                  label: 'Description',
                  child: TextField(
                    controller: descCtrl,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Add description',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GridFormCard(
                  label: 'Category',
                  onTap: onCategoryTap,
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            categoryLabel,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GridFormCard(
                  label: 'Price',
                  child: TextField(
                    controller: amtCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Enter price',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                    onChanged: (_) => onAmountChanged(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GridFormCard(
                  label: 'Paid By',
                  onTap: onPaidByTap,
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            payerLabel,
                            style: TextStyle(
                                color: form.singlePayerId.isEmpty &&
                                        form.payerType == 'single'
                                    ? AppTheme.textMuted
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Split Options Row
// ─────────────────────────────────────────────────────────────────────────────
class _SplitOptionsRow extends StatelessWidget {
  final String currentSplit;
  final VoidCallback onEqualTap;
  final VoidCallback onUnequalTap;
  final VoidCallback onItemWiseTap;

  const _SplitOptionsRow({
    required this.currentSplit,
    required this.onEqualTap,
    required this.onUnequalTap,
    required this.onItemWiseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Split',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SplitSegment(
                    label: 'Equally',
                    isSelected: currentSplit == 'equal',
                    onTap: onEqualTap,
                  ),
                ),
                Expanded(
                  child: _SplitSegment(
                    label: 'Unequally',
                    isSelected: currentSplit == 'unequalAmount' ||
                        currentSplit == 'unequalShares',
                    onTap: onUnequalTap,
                  ),
                ),
                Expanded(
                  child: _SplitSegment(
                    label: 'Item wise',
                    isSelected: currentSplit == 'itemWise',
                    onTap: onItemWiseTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SplitSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Equal Split Preview
// ─────────────────────────────────────────────────────────────────────────────
class _EqualSplitPreview extends ConsumerWidget {
  final List<GroupMemberModel> allMembers;
  final List<String> selectedIds;
  final double amount;

  const _EqualSplitPreview({
    super.key,
    required this.allMembers,
    required this.selectedIds,
    required this.amount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (allMembers.isEmpty) return const SizedBox.shrink();

    final activeCount = selectedIds.length;
    final share = activeCount > 0 ? amount / activeCount : 0.0;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final authState = ref.watch(authStateNotifierProvider);
    final myUid = authState is AuthAuthenticated ? authState.user.uid : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Split among ( Tap to unselect )',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: allMembers.map((m) {
              final selected = selectedIds.contains(m.userId);
              return GestureDetector(
                onTap: () {
                  final selectionNotifier = ref.read(memberSelectionProvider.notifier);
                  selectionNotifier.toggle(m.userId);
                  final updatedSelection = ref.read(memberSelectionProvider);
                  ref.read(addExpenseProvider.notifier).setEqualSplit(updatedSelection);
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 52) / 3,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.userId == myUid ? 'You' : m.userName.split(' ').first,
                        style: TextStyle(
                          color: selected ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selected ? fmt.format(share) : '₹ 0',
                        style: TextStyle(
                          color: selected ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save Button Bar
// ─────────────────────────────────────────────────────────────────────────────
class _SaveBar extends StatelessWidget {
  final bool canSave;
  final bool saving;
  final Future<void> Function() onSave;

  const _SaveBar(
      {required this.canSave, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: canSave ? onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            disabledBackgroundColor: AppTheme.borderLight,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Text('Save Expense',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bill Tabs Row & Bottom Actions Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BillTabsRow extends ConsumerWidget {
  const _BillTabsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsState = ref.watch(billTabsProvider);
    final notifier = ref.read(billTabsProvider.notifier);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...tabsState.tabs.asMap().entries.map((e) {
              final idx = e.key;
              final active = idx == tabsState.activeIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    final currentTabState = ref.read(addExpenseProvider);
                    notifier.updateActiveTab(currentTabState);
                    notifier.switchTab(idx);
                    ref.read(addExpenseProvider.notifier).restore(tabsState.tabs[idx]);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFF59E0B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Bill ${idx + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : const Color(0xFF475569),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        if (tabsState.tabs.length > 1) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              notifier.removeBill(idx);
                              final newTabsState = ref.read(billTabsProvider);
                              ref.read(addExpenseProvider.notifier).restore(newTabsState.activeTab);
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: active ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () {
                final currentTabState = ref.read(addExpenseProvider);
                notifier.updateActiveTab(currentTabState);
                notifier.addBill();
                final newTabsState = ref.read(billTabsProvider);
                ref.read(addExpenseProvider.notifier).restore(newTabsState.activeTab);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: Color(0xFF475569)),
                    SizedBox(width: 4),
                    Text(
                      'Add bill',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionsRow extends ConsumerWidget {
  final List<File> images;
  final ValueChanged<List<File>> onImagesChanged;

  const _BottomActionsRow({
    required this.images,
    required this.onImagesChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(addExpenseProvider);
    final date = form.date;
    final formattedDate = DateFormat('d MMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.camera_alt_outlined,
              label: images.isEmpty ? 'Add image' : '${images.length} image(s)',
              onTap: () => _pickImage(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan bill',
              onTap: () => _scanBill(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.calendar_today_rounded,
              label: formattedDate,
              onTap: () => _pickDate(context, ref, date),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add Image', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Choose a source for the receipt image:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
          ],
        ),
      );

      if (source != null) {
        final picked = await picker.pickImage(imageQuality: 70, source: source);
        if (picked != null) {
          onImagesChanged([...images, File(picked.path)]);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _scanBill(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill scanning features are currently integrated with QR code flow.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6366F1),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(addExpenseProvider.notifier).updateDate(picked);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF6366F1), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
