import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/expense_category.dart';
import '../providers/add_expense_providers.dart';

/// Bottom sheet for selecting an expense category.
///
/// Validates: Requirements 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9
class CategorySheet extends ConsumerWidget {
  const CategorySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCategories = ref.watch(customCategoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Category',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: ExpenseCategory.selectableCategories.length +
                    customCategories.length +
                    1,
                itemBuilder: (_, i) {
                  final builtIn = ExpenseCategory.selectableCategories;

                  // Custom categories
                  if (i >= builtIn.length && i < builtIn.length + customCategories.length) {
                    final custom = customCategories[i - builtIn.length];
                    return _CategoryTile(
                      icon: Icons.label_rounded,
                      label: custom,
                      color: Colors.orange,
                      onTap: () {
                        ref
                            .read(addExpenseProvider.notifier)
                            .updateCategory(custom);
                        Navigator.pop(context);
                      },
                    );
                  }

                  // "Add Custom" tile
                  if (i == builtIn.length + customCategories.length) {
                    return _CategoryTile(
                      icon: Icons.add_rounded,
                      label: 'Add Custom',
                      color: AppTheme.primaryPurple,
                      onTap: () => _showCustomDialog(context, ref),
                    );
                  }

                  // Built-in categories
                  final cat = builtIn[i];
                  return _CategoryTile(
                    icon: cat.icon,
                    label: cat.label,
                    color: _categoryColor(cat),
                    onTap: () {
                      ref
                          .read(addExpenseProvider.notifier)
                          .updateCategory(cat.name);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showCustomDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Custom Category',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Category name',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primaryPurple, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              ref.read(customCategoriesProvider.notifier).add(name);
              ref.read(addExpenseProvider.notifier).updateCategory(name);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close sheet
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(ExpenseCategory cat) {
    const colors = {
      ExpenseCategory.food: Color(0xFFEF4444),
      ExpenseCategory.groceries: Color(0xFF22C55E),
      ExpenseCategory.travel: Color(0xFF3B82F6),
      ExpenseCategory.stay: Color(0xFF8B5CF6),
      ExpenseCategory.bills: Color(0xFFF59E0B),
      ExpenseCategory.subscription: Color(0xFF06B6D4),
      ExpenseCategory.shopping: Color(0xFFEC4899),
      ExpenseCategory.gifts: Color(0xFFFF6B6B),
      ExpenseCategory.drinks: Color(0xFF7C3AED),
      ExpenseCategory.fuel: Color(0xFF059669),
      ExpenseCategory.udhaar: Color(0xFFF97316),
      ExpenseCategory.health: Color(0xFF10B981),
      ExpenseCategory.entertainment: Color(0xFFE11D48),
      ExpenseCategory.misc: Color(0xFF6B7280),
    };
    return colors[cat] ?? AppTheme.primaryPurple;
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
