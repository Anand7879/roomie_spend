import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_member_model.dart';
import '../providers/add_expense_providers.dart';

/// Bottom sheet with "Single Payer" and "Multi Payer" tabs.
/// Validates: Requirements 9.2–9.7, 10.1–10.7
class PaidBySheet extends ConsumerStatefulWidget {
  final List<GroupMemberModel> selectedMembers;
  final double expenseAmount;

  const PaidBySheet({
    super.key,
    required this.selectedMembers,
    required this.expenseAmount,
  });

  @override
  ConsumerState<PaidBySheet> createState() => _PaidBySheetState();
}

class _PaidBySheetState extends ConsumerState<PaidBySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _selectedPayerId = '';
  String _selectedPayerName = '';
  late Map<String, double> _payerAmounts;

  @override
  void initState() {
    super.initState();
    final formState = ref.read(addExpenseProvider);
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: formState.payerType == 'multi' ? 1 : 0,
    );
    _selectedPayerId = formState.singlePayerId;
    _selectedPayerName = formState.singlePayerName;
    _payerAmounts = Map.from(formState.multiPayerAmounts);
    // Pre-populate multi-payer amounts if empty
    if (_payerAmounts.isEmpty) {
      for (final m in widget.selectedMembers) {
        _payerAmounts[m.userId] = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  double get _remaining =>
      widget.expenseAmount -
      _payerAmounts.values.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
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
                  _SinglePayerTab(
                    members: widget.selectedMembers,
                    selectedId: _selectedPayerId,
                    onSelect: (id, name) =>
                        setState(() {
                          _selectedPayerId = id;
                          _selectedPayerName = name;
                        }),
                    controller: controller,
                  ),
                  _MultiPayerTab(
                    members: widget.selectedMembers,
                    amounts: _payerAmounts,
                    remaining: _remaining,
                    expenseAmount: widget.expenseAmount,
                    onChanged: (id, val) =>
                        setState(() => _payerAmounts[id] = val),
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
          child: Text(
            'Who Paid?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );

  Widget _buildTabBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textSecondary,
            indicator: BoxDecoration(
              color: AppTheme.primaryPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [Tab(text: 'Single Payer'), Tab(text: 'Multi Payer')],
          ),
        ),
      );

  Widget _buildConfirmButton() {
    final isMulti = _tabCtrl.index == 1;
    final isValid = isMulti
        ? _remaining.abs() < 0.01
        : _selectedPayerId.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isValid ? _confirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            disabledBackgroundColor: AppTheme.borderLight,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            isMulti ? 'Confirm Payers' : 'Confirm',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final notifier = ref.read(addExpenseProvider.notifier);
    if (_tabCtrl.index == 1) {
      notifier.setMultiPayer(_payerAmounts);
    } else {
      notifier.setSinglePayer(_selectedPayerId, _selectedPayerName);
    }
    Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SinglePayerTab extends StatelessWidget {
  final List<GroupMemberModel> members;
  final String selectedId;
  final void Function(String id, String name) onSelect;
  final ScrollController controller;

  const _SinglePayerTab({
    required this.members,
    required this.selectedId,
    required this.onSelect,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final selected = m.userId == selectedId;
        return GestureDetector(
          onTap: () => onSelect(m.userId, m.userName),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.lightPurpleContainer
                  : AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryPurple
                    : AppTheme.borderLight,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(m.userAvatar.isNotEmpty ? m.userAvatar : '👤',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.userName,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.primaryPurple
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppTheme.primaryPurple
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryPurple
                          : AppTheme.borderLight,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 13)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MultiPayerTab extends StatelessWidget {
  final List<GroupMemberModel> members;
  final Map<String, double> amounts;
  final double remaining;
  final double expenseAmount;
  final void Function(String id, double val) onChanged;
  final ScrollController controller;

  const _MultiPayerTab({
    required this.members,
    required this.amounts,
    required this.remaining,
    required this.expenseAmount,
    required this.onChanged,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isBalanced = remaining.abs() < 0.01;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: members.length,
            itemBuilder: (_, i) {
              final m = members[i];
              return _AmountInputTile(
                member: m,
                value: amounts[m.userId] ?? 0.0,
                onChanged: (v) => onChanged(m.userId, v),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isBalanced
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isBalanced
                  ? AppTheme.successGreen
                  : const Color(0xFFFB923C),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBalanced ? '✓ Amounts balanced' : 'Remaining',
                style: TextStyle(
                  color: isBalanced
                      ? AppTheme.successGreen
                      : const Color(0xFFF97316),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '₹${remaining.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: isBalanced
                      ? AppTheme.successGreen
                      : const Color(0xFFF97316),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountInputTile extends StatefulWidget {
  final GroupMemberModel member;
  final double value;
  final ValueChanged<double> onChanged;

  const _AmountInputTile({
    required this.member,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AmountInputTile> createState() => _AmountInputTileState();
}

class _AmountInputTileState extends State<_AmountInputTile> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value > 0 ? widget.value.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          Text(
            widget.member.userAvatar.isNotEmpty
                ? widget.member.userAvatar
                : '👤',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.member.userName,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                prefixText: '₹',
                prefixStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                hintText: '0.00',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryPurple, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.borderLight),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
              ),
              onChanged: (v) =>
                  widget.onChanged(double.tryParse(v) ?? 0.0),
            ),
          ),
        ],
      ),
    );
  }
}
