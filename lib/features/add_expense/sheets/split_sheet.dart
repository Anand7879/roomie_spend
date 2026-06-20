import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_member_model.dart';
import '../providers/add_expense_providers.dart';

/// Bottom sheet with "By Amount" and "By Shares" tabs for unequal splits.
/// Validates: Requirements 12.1–12.7, 13.1–13.5
class SplitSheet extends ConsumerStatefulWidget {
  final List<GroupMemberModel> selectedMembers;
  final double expenseAmount;

  const SplitSheet({
    super.key,
    required this.selectedMembers,
    required this.expenseAmount,
  });

  @override
  ConsumerState<SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends ConsumerState<SplitSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Map<String, double> _amounts;
  late Map<String, int> _shares;

  @override
  void initState() {
    super.initState();
    final formState = ref.read(addExpenseProvider);
    final isShares = formState.splitType == 'unequalShares';
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: isShares ? 1 : 0);
    _amounts = Map.from(formState.unequalAmounts);
    _shares = Map.from(formState.unequalShares);
    for (final m in widget.selectedMembers) {
      _amounts.putIfAbsent(m.userId, () => 0.0);
      _shares.putIfAbsent(m.userId, () => 1);
    }
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  double get _amountRemaining =>
      widget.expenseAmount - _amounts.values.fold(0.0, (a, b) => a + b);

  int get _totalShares => _shares.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ByAmountTab(
                    members: widget.selectedMembers,
                    amounts: _amounts,
                    remaining: _amountRemaining,
                    expenseAmount: widget.expenseAmount,
                    onChanged: (id, v) => setState(() => _amounts[id] = v),
                    controller: controller,
                  ),
                  _BySharesTab(
                    members: widget.selectedMembers,
                    shares: _shares,
                    totalShares: _totalShares,
                    expenseAmount: widget.expenseAmount,
                    onChanged: (id, v) => setState(() => _shares[id] = v),
                    controller: controller,
                  ),
                ],
              ),
            ),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _buildHeader() => const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Split Unequally',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ),
      );

  Widget _buildTabBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF64748B),
            indicator: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [Tab(text: 'By Amount'), Tab(text: 'By Shares')],
          ),
        ),
      );

  Widget _buildConfirmButton() {
    final isShares = _tabCtrl.index == 1;
    final isValid = isShares
        ? _totalShares > 0
        : _amountRemaining.abs() < 0.01;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isValid ? _confirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFF94A3B8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26)),
            elevation: 0,
          ),
          child: const Text('Confirm Split',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    );
  }

  void _confirm() {
    final notifier = ref.read(addExpenseProvider.notifier);
    if (_tabCtrl.index == 1) {
      notifier.setUnequalByShares(_shares);
    } else {
      notifier.setUnequalByAmount(_amounts);
    }
    Navigator.pop(context);
  }
}

// ─── By Amount Tab ────────────────────────────────────────────────────────────
class _ByAmountTab extends StatelessWidget {
  final List<GroupMemberModel> members;
  final Map<String, double> amounts;
  final double remaining;
  final double expenseAmount;
  final void Function(String, double) onChanged;
  final ScrollController controller;

  const _ByAmountTab({
    required this.members,
    required this.amounts,
    required this.remaining,
    required this.expenseAmount,
    required this.onChanged,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final activePeopleCount = amounts.values.where((v) => v > 0.01).length;
    final totalPeopleCount = members.length;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: members.length,
            itemBuilder: (_, i) => _AmountRow(
              member: members[i],
              value: amounts[members[i].userId] ?? 0.0,
              onChanged: (v) => onChanged(members[i].userId, v),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'People : $activePeopleCount / $totalPeopleCount',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                'Remaining : ₹${remaining.toStringAsFixed(0)} / ₹${expenseAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: remaining.abs() < 0.01 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── By Shares Tab ────────────────────────────────────────────────────────────
class _BySharesTab extends StatelessWidget {
  final List<GroupMemberModel> members;
  final Map<String, int> shares;
  final int totalShares;
  final double expenseAmount;
  final void Function(String, int) onChanged;
  final ScrollController controller;

  const _BySharesTab({
    required this.members,
    required this.shares,
    required this.totalShares,
    required this.expenseAmount,
    required this.onChanged,
    required this.controller,
  });

  Widget _buildAmountPreview() {
    final activeMembers = members.where((m) => (shares[m.userId] ?? 0) > 0).toList();
    if (activeMembers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Amount Preview',
            style: TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 54,
          child: ListView.builder(
             scrollDirection: Axis.horizontal,
             padding: const EdgeInsets.symmetric(horizontal: 12),
             itemCount: activeMembers.length,
             itemBuilder: (_, i) {
               final m = activeMembers[i];
               final memberShare = shares[m.userId] ?? 1;
               final memberAmount = totalShares > 0
                   ? (memberShare / totalShares) * expenseAmount
                   : 0.0;
               return Container(
                 margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                 decoration: BoxDecoration(
                   color: const Color(0xFFEEF2F6),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: const Color(0xFFE2E8F0)),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text(m.userAvatar.isNotEmpty ? m.userAvatar : '👤'),
                     const SizedBox(width: 6),
                     Text(
                       m.userName,
                       style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                     ),
                     const SizedBox(width: 6),
                     Text(
                       '₹${memberAmount.toStringAsFixed(0)}',
                       style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                     ),
                   ],
                 ),
               );
             },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePeopleCount = shares.values.where((v) => v > 0).length;
    final totalPeopleCount = members.length;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: members.length,
            itemBuilder: (_, i) {
              final m = members[i];
              final memberShare = shares[m.userId] ?? 1;
              final memberAmount = totalShares > 0
                  ? (memberShare / totalShares) * expenseAmount
                  : 0.0;
              return _ShareRow(
                member: m,
                share: memberShare,
                amount: memberAmount,
                onChanged: (v) => onChanged(m.userId, v),
              );
            },
          ),
        ),
        _buildAmountPreview(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'People : $activePeopleCount / $totalPeopleCount',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                'Remaining : ₹${totalShares > 0 ? 0 : expenseAmount.toStringAsFixed(0)} / ₹${expenseAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: totalShares > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _AmountRow extends StatefulWidget {
  final GroupMemberModel member;
  final double value;
  final ValueChanged<double> onChanged;

  const _AmountRow({required this.member, required this.value, required this.onChanged});

  @override
  State<_AmountRow> createState() => _AmountRowState();
}

class _AmountRowState extends State<_AmountRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value > 0 ? widget.value.toStringAsFixed(2) : '');
  }

  @override
  void didUpdateWidget(covariant _AmountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newText = widget.value > 0 ? widget.value.toStringAsFixed(2) : '';
      if (_ctrl.text != newText && !(widget.value == 0.0 && _ctrl.text.isEmpty)) {
        _ctrl.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = widget.value > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (isChecked) {
                widget.onChanged(0.0);
                _ctrl.text = '';
              } else {
                widget.onChanged(0.0);
              }
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFF6366F1) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(widget.member.userAvatar.isNotEmpty ? widget.member.userAvatar : '👤',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.member.userName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
              decoration: InputDecoration(
                prefixText: '₹',
                prefixStyle:
                    const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                hintText: '0.00',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final GroupMemberModel member;
  final int share;
  final double amount;
  final ValueChanged<int> onChanged;

  const _ShareRow({
    required this.member,
    required this.share,
    required this.amount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isChecked = share > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (isChecked) {
                onChanged(0);
              } else {
                onChanged(1);
              }
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFF6366F1) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(member.userAvatar.isNotEmpty ? member.userAvatar : '👤',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.userName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text('≈ ₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onTap: isChecked && share > 1
                    ? () => onChanged(share - 1)
                    : null,
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  '$share',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                onTap: isChecked
                    ? () => onChanged(share + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? const Color(0xFF6366F1) : const Color(0xFF94A3B8)),
      ),
    );
  }
}
