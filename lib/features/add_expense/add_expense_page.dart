import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: const Color(0xFFF7F8FC),
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
                if (form.splitType == 'equal' && selectedMembers.isNotEmpty) ...[
                  _EqualSplitPreview(
                    members: selectedMembers,
                    amount: double.tryParse(_amtCtrl.text) ?? 0.0,
                    allMembers: _allMembers,
                    selectedIds: selectedMemberIds,
                  ),
                ],

                // ── Date picker ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DatePickerCard(),
                ),

                // ── Image attachment ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: ImageAttachmentSection(
                    images: _localImages,
                    onChanged: (imgs) => setState(() => _localImages = imgs),
                  ),
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
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Expense',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            widget.group.groupName,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.lightPurpleContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${widget.group.groupIcon} ${widget.group.groupName}',
            style: const TextStyle(
              color: AppTheme.primaryPurple,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
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
                    decoration: BoxDecoration(
                      color: AppTheme.lightPurpleContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primaryPurple.withOpacity(0.3),
                          width: 1.5,
                          style: BorderStyle.solid),
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: AppTheme.primaryPurple, size: 22),
                  ),
                  const SizedBox(height: 4),
                  const Text('Add\nFriends',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.primaryPurple,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
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
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primaryPurple, width: 2),
              ),
              child: Center(
                child: Text(
                  member.userAvatar.isNotEmpty ? member.userAvatar : '👤',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: AppTheme.errorRed, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          member.userName.split(' ').first,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600),
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
    ('📱', 'PhonePe'),
    ('💳', 'GPay'),
    ('🔵', 'Paytm'),
    ('🚗', 'Uber'),
    ('🍔', 'Swiggy'),
    ('🍕', 'Zomato'),
    ('⚡', 'Zepto'),
    ('🛒', 'Blinkit'),
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
                                color: AppTheme.backgroundLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.borderLight, width: 1),
                              ),
                              child: Center(
                                child: Text(l.$1,
                                    style: const TextStyle(fontSize: 18)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(l.$2,
                                style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          Row(
            children: [
              Expanded(
                  child: Container(
                      height: 1, color: AppTheme.borderLight)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(
                  child: Container(
                      height: 1, color: AppTheme.borderLight)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Form Card
// ─────────────────────────────────────────────────────────────────────────────
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
    final payerLabel = form.payerType == 'multi'
        ? 'Multiple Payers'
        : form.singlePayerName.isNotEmpty
            ? form.singlePayerName
            : 'Select Payer';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Category row
          _FormRow(
            icon: category.icon,
            iconColor: const Color(0xFF8B5CF6),
            onTap: onCategoryTap,
            child: Text(
              category == ExpenseCategory.misc &&
                      !ExpenseCategory.values
                          .any((c) => c.name == form.category)
                  ? form.category
                  : category.label,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
          _divider(),

          // Description field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: descCtrl,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Add a description',
                hintStyle:
                    TextStyle(color: AppTheme.textMuted, fontSize: 15),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.edit_rounded,
                    color: AppTheme.textMuted, size: 18),
              ),
            ),
          ),
          _divider(),

          // Amount field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: amtCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'))
              ],
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22),
              decoration: const InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 22),
                border: InputBorder.none,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(top: 12, left: 4),
                  child: Text('₹',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              onChanged: (_) => onAmountChanged(),
            ),
          ),
          _divider(),

          // Paid by row
          _FormRow(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF3B82F6),
            onTap: onPaidByTap,
            child: Text(
              payerLabel,
              style: TextStyle(
                  color: form.singlePayerId.isEmpty &&
                          form.payerType == 'single'
                      ? AppTheme.textMuted
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
          _divider(),

          // Notes field
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: notesCtrl,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Notes (optional)',
                hintStyle:
                    TextStyle(color: AppTheme.textMuted, fontSize: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.notes_rounded,
                    color: AppTheme.textMuted, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, thickness: 1, color: AppTheme.borderLight,
      indent: 16, endIndent: 16);
}

class _FormRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget child;

  const _FormRow({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(child: child),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMuted, size: 20),
          ],
        ),
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
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SplitChip(
                  label: '= Equal',
                  isSelected: currentSplit == 'equal',
                  onTap: onEqualTap),
              const SizedBox(width: 8),
              _SplitChip(
                  label: '≠ Unequal',
                  isSelected: currentSplit == 'unequalAmount' ||
                      currentSplit == 'unequalShares',
                  onTap: onUnequalTap),
              const SizedBox(width: 8),
              _SplitChip(
                  label: '📦 Items',
                  isSelected: currentSplit == 'itemWise',
                  onTap: onItemWiseTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _SplitChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SplitChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurple
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryPurple
                : AppTheme.borderLight,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Equal Split Preview
// ─────────────────────────────────────────────────────────────────────────────
class _EqualSplitPreview extends StatelessWidget {
  final List<GroupMemberModel> members;
  final double amount;
  final List<GroupMemberModel> allMembers;
  final List<String> selectedIds;

  const _EqualSplitPreview({
    required this.members,
    required this.amount,
    required this.allMembers,
    required this.selectedIds,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty || amount <= 0) return const SizedBox.shrink();
    final share = amount / members.length;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded,
                  color: AppTheme.primaryPurple, size: 16),
              const SizedBox(width: 6),
              Text(
                '${members.length} members · ${fmt.format(share)} each',
                style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: members.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.lightPurpleContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${m.userAvatar} ${m.userName.split(' ').first}  ${fmt.format(share)}',
                  style: const TextStyle(
                      color: AppTheme.primaryPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
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
            backgroundColor: AppTheme.primaryPurple,
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
