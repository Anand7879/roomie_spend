import 'package:flutter/material.dart';

/// Enum representing all available expense categories with their associated icons and labels
enum ExpenseCategory {
  food(icon: Icons.restaurant, label: 'Food'),
  groceries(icon: Icons.shopping_cart, label: 'Groceries'),
  travel(icon: Icons.directions_car, label: 'Travel'),
  stay(icon: Icons.hotel, label: 'Stay'),
  bills(icon: Icons.receipt, label: 'Bills'),
  subscription(icon: Icons.subscriptions, label: 'Subscription'),
  shopping(icon: Icons.shopping_bag, label: 'Shopping'),
  gifts(icon: Icons.card_giftcard, label: 'Gifts'),
  drinks(icon: Icons.local_bar, label: 'Drinks'),
  fuel(icon: Icons.local_gas_station, label: 'Fuel'),
  udhaar(icon: Icons.handshake, label: 'Udhaar (Debt)'),
  health(icon: Icons.health_and_safety, label: 'Health'),
  entertainment(icon: Icons.movie, label: 'Entertainment'),
  misc(icon: Icons.more_horiz, label: 'Misc.'),
  custom(icon: Icons.add, label: 'Add Custom');

  const ExpenseCategory({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  /// Returns the ExpenseCategory from a string value
  /// Falls back to misc if the category is not found
  static ExpenseCategory fromString(String value) {
    try {
      return ExpenseCategory.values.firstWhere(
        (category) =>
            category.name.toLowerCase() == value.toLowerCase() ||
            category.label.toLowerCase() == value.toLowerCase(),
        orElse: () => ExpenseCategory.misc,
      );
    } catch (e) {
      return ExpenseCategory.misc;
    }
  }

  /// Returns the string value of the category (name)
  String toStringValue() {
    return name;
  }

  /// Returns whether this is a custom category
  bool get isCustom => this == ExpenseCategory.custom;

  /// Returns all selectable categories (excludes custom)
  static List<ExpenseCategory> get selectableCategories {
    return ExpenseCategory.values
        .where((category) => category != ExpenseCategory.custom)
        .toList();
  }

  /// Returns all categories including the custom option
  static List<ExpenseCategory> get allCategories {
    return ExpenseCategory.values;
  }
}
