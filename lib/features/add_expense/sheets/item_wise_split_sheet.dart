import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_member_model.dart';
import '../../../models/split_config.dart';
import '../providers/add_expense_providers.dart';

/// Full item-wise split sheet.
/// Validates: Requirements 14.1–14.12
class ItemWiseSplitSheet extends ConsumerStatefulWidget {
  final List<GroupMemberModel> selectedMembers;
  final double expenseAmount;

  const ItemWiseSplitSheet({
    super.key,
    required this.selectedMembers,
    required this.expenseAmount,
  });

  @override
  ConsumerState<ItemWiseSplitSheet> createState() => _ItemWiseSplitSheetState();
}

class _ItemWiseSplitSheetState extends ConsumerState<ItemWiseSplitSheet> {
  late List<_ItemEntry> _items;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(addExpenseProvider).itemWiseSplits;
    if (existing.isNotEmpty) {
      _items = existing
          .map((s) => _ItemEntry.fromSplitItem(s, widget.selectedMembers))
          .toList();
    } else {
      _items = [_ItemEntry.empty(widget.selectedMembers)];
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  double get _itemsTotal =>
      _items.fold(0.0, (s, i) => s + i.total);

  double get _remaining => widget.expenseAmount - _itemsTotal;
  bool get _isBalanced => _remaining.abs() < 0.01;

  void _addItem() {
    setState(() => _items.add(_ItemEntry.empty(widget.selectedMembers)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() => _items.removeAt(index));
  }

  void _splitAllEqually() {
    if (_items.isEmpty) return;
    final share = widget.expenseAmount / _items.length;
    setState(() {
      for (int i = 0; i < _items.length; i++) {
        final adj = i == _items.length - 1
            ? widget.expenseAmount - share * (_items.length - 1)
            : share;
        _items[i] = _items[i].copyWith(
          quantity: 1,
          pricePerUnit: adj,
          memberIds: widget.selectedMembers.map((m) => m.userId).toList(),
        );
      }
    });
  }

  void _confirm() {
    final splits = _items.map((e) => e.toSplitItem()).toList();
    ref.read(addExpenseProvider.notifier).setItemWiseSplit(splits);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ..._items.asMap().entries.map((e) => _ItemCard(
                        key: ValueKey(e.key),
                        entry: e.value,
                        index: e.key,
                        allMembers: widget.selectedMembers,
                        onChanged: (updated) =>
                            setState(() => _items[e.key] = updated),
                        onDelete: _items.length > 1
                            ? () => _removeItem(e.key)
                            : null,
                      )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _buildButtons(),
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
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Item-Wise Split',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: _splitAllEqually,
                  icon: const Icon(Icons.splitscreen_rounded, size: 16, color: Color(0xFF6366F1)),
                  label: const Text(
                    'Split All Equally',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF2F6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Remaining: ₹${_remaining.toStringAsFixed(0)} / ₹${widget.expenseAmount.toStringAsFixed(0)}',
              style: TextStyle(
                color: _isBalanced ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(height: 20, thickness: 1, color: Color(0xFFF1F5F9)),
          ],
        ),
      );

  Widget _buildButtons() => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF6366F1), size: 20),
                  label: const Text(
                    'Add Item',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isBalanced ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: const Text('Done',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Item Entry (mutable state for editing) ───────────────────────────────────
class _ItemEntry {
  final String description;
  final int quantity;
  final double pricePerUnit;
  final List<String> memberIds;

  const _ItemEntry({
    required this.description,
    required this.quantity,
    required this.pricePerUnit,
    required this.memberIds,
  });

  factory _ItemEntry.empty(List<GroupMemberModel> allMembers) => _ItemEntry(
        description: '',
        quantity: 1,
        pricePerUnit: 0.0,
        memberIds: allMembers.map((m) => m.userId).toList(),
      );

  factory _ItemEntry.fromSplitItem(
      SplitItem item, List<GroupMemberModel> allMembers) =>
      _ItemEntry(
        description: item.description,
        quantity: item.quantity,
        pricePerUnit: item.pricePerUnit,
        memberIds: item.memberIds,
      );

  double get total => quantity * pricePerUnit;

  SplitItem toSplitItem() => SplitItem(
        description: description,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        memberIds: memberIds,
      );

  _ItemEntry copyWith({
    String? description,
    int? quantity,
    double? pricePerUnit,
    List<String>? memberIds,
  }) =>
      _ItemEntry(
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        pricePerUnit: pricePerUnit ?? this.pricePerUnit,
        memberIds: memberIds ?? this.memberIds,
      );
}

// ─── Item Card ────────────────────────────────────────────────────────────────
class _ItemCard extends StatefulWidget {
  final _ItemEntry entry;
  final int index;
  final List<GroupMemberModel> allMembers;
  final ValueChanged<_ItemEntry> onChanged;
  final VoidCallback? onDelete;

  const _ItemCard({
    super.key,
    required this.entry,
    required this.index,
    required this.allMembers,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.entry.description);
    _priceCtrl = TextEditingController(
        text: widget.entry.pricePerUnit > 0
            ? widget.entry.pricePerUnit.toStringAsFixed(2)
            : '');
  }

  @override
  void didUpdateWidget(covariant _ItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.description != oldWidget.entry.description) {
      if (_descCtrl.text != widget.entry.description) {
        _descCtrl.text = widget.entry.description;
      }
    }
    if (widget.entry.pricePerUnit != oldWidget.entry.pricePerUnit) {
      final newText = widget.entry.pricePerUnit > 0
          ? widget.entry.pricePerUnit.toStringAsFixed(2)
          : '';
      if (_priceCtrl.text != newText && !(widget.entry.pricePerUnit == 0.0 && _priceCtrl.text.isEmpty)) {
        _priceCtrl.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle),
                  child: Center(
                    child: Text('${widget.index + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _descCtrl,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Item name',
                      hintStyle: TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) => widget
                        .onChanged(entry.copyWith(description: v)),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.errorRed, size: 20),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 16),
          // Quantity + Price row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Quantity
                const Text('Qty',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                _StepBtn(
                  icon: Icons.remove_rounded,
                  enabled: entry.quantity > 1,
                  onTap: () => widget.onChanged(
                      entry.copyWith(quantity: entry.quantity - 1)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${entry.quantity}',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                _StepBtn(
                  icon: Icons.add_rounded,
                  enabled: true,
                  onTap: () => widget.onChanged(
                      entry.copyWith(quantity: entry.quantity + 1)),
                ),
                const Spacer(),
                // Price
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                    decoration: InputDecoration(
                      prefixText: '₹',
                      prefixStyle: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600),
                      hintText: '0.00',
                      hintStyle:
                          const TextStyle(color: AppTheme.textMuted),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF6366F1), width: 1.5)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => widget.onChanged(
                        entry.copyWith(
                            pricePerUnit: double.tryParse(v) ?? 0.0)),
                  ),
                ),
              ],
            ),
          ),
          // Total
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: ₹${entry.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          // Member chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assign to:',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.allMembers.map((m) {
                    final selected = entry.memberIds.contains(m.userId);
                    return GestureDetector(
                      onTap: () {
                        final updated = List<String>.from(entry.memberIds);
                        if (selected) {
                          if (updated.length > 1) updated.remove(m.userId);
                        } else {
                          updated.add(m.userId);
                        }
                        widget.onChanged(entry.copyWith(memberIds: updated));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${m.userAvatar} ${m.userName}',
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 15,
            color:
                enabled ? const Color(0xFF6366F1) : const Color(0xFF94A3B8)),
      ),
    );
  }
}

// Removed _AddItemButton since it is now built inline in the bottom buttons row.
