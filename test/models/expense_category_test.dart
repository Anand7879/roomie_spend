import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomie_spend/models/expense_category.dart';

void main() {
  group('ExpenseCategory', () {
    test('should have all required categories', () {
      expect(ExpenseCategory.values.length, 15);
      expect(ExpenseCategory.values.contains(ExpenseCategory.food), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.groceries), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.travel), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.stay), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.bills), true);
      expect(
          ExpenseCategory.values.contains(ExpenseCategory.subscription), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.shopping), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.gifts), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.drinks), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.fuel), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.udhaar), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.health), true);
      expect(
          ExpenseCategory.values.contains(ExpenseCategory.entertainment), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.misc), true);
      expect(ExpenseCategory.values.contains(ExpenseCategory.custom), true);
    });

    test('should have correct icons for each category', () {
      expect(ExpenseCategory.food.icon, Icons.restaurant);
      expect(ExpenseCategory.groceries.icon, Icons.shopping_cart);
      expect(ExpenseCategory.travel.icon, Icons.directions_car);
      expect(ExpenseCategory.stay.icon, Icons.hotel);
      expect(ExpenseCategory.bills.icon, Icons.receipt);
      expect(ExpenseCategory.subscription.icon, Icons.subscriptions);
      expect(ExpenseCategory.shopping.icon, Icons.shopping_bag);
      expect(ExpenseCategory.gifts.icon, Icons.card_giftcard);
      expect(ExpenseCategory.drinks.icon, Icons.local_bar);
      expect(ExpenseCategory.fuel.icon, Icons.local_gas_station);
      expect(ExpenseCategory.udhaar.icon, Icons.handshake);
      expect(ExpenseCategory.health.icon, Icons.health_and_safety);
      expect(ExpenseCategory.entertainment.icon, Icons.movie);
      expect(ExpenseCategory.misc.icon, Icons.more_horiz);
      expect(ExpenseCategory.custom.icon, Icons.add);
    });

    test('should have correct labels for each category', () {
      expect(ExpenseCategory.food.label, 'Food');
      expect(ExpenseCategory.groceries.label, 'Groceries');
      expect(ExpenseCategory.travel.label, 'Travel');
      expect(ExpenseCategory.stay.label, 'Stay');
      expect(ExpenseCategory.bills.label, 'Bills');
      expect(ExpenseCategory.subscription.label, 'Subscription');
      expect(ExpenseCategory.shopping.label, 'Shopping');
      expect(ExpenseCategory.gifts.label, 'Gifts');
      expect(ExpenseCategory.drinks.label, 'Drinks');
      expect(ExpenseCategory.fuel.label, 'Fuel');
      expect(ExpenseCategory.udhaar.label, 'Udhaar (Debt)');
      expect(ExpenseCategory.health.label, 'Health');
      expect(ExpenseCategory.entertainment.label, 'Entertainment');
      expect(ExpenseCategory.misc.label, 'Misc.');
      expect(ExpenseCategory.custom.label, 'Add Custom');
    });

    test('should parse category from string by name', () {
      expect(ExpenseCategory.fromString('food'), ExpenseCategory.food);
      expect(ExpenseCategory.fromString('groceries'), ExpenseCategory.groceries);
      expect(ExpenseCategory.fromString('travel'), ExpenseCategory.travel);
      expect(ExpenseCategory.fromString('BILLS'), ExpenseCategory.bills);
    });

    test('should parse category from string by label', () {
      expect(ExpenseCategory.fromString('Food'), ExpenseCategory.food);
      expect(ExpenseCategory.fromString('Groceries'), ExpenseCategory.groceries);
      expect(ExpenseCategory.fromString('Udhaar (Debt)'), ExpenseCategory.udhaar);
    });

    test('should return misc for unknown category', () {
      expect(ExpenseCategory.fromString('unknown'), ExpenseCategory.misc);
      expect(ExpenseCategory.fromString(''), ExpenseCategory.misc);
      expect(ExpenseCategory.fromString('invalid'), ExpenseCategory.misc);
    });

    test('should convert category to string value', () {
      expect(ExpenseCategory.food.toStringValue(), 'food');
      expect(ExpenseCategory.groceries.toStringValue(), 'groceries');
      expect(ExpenseCategory.udhaar.toStringValue(), 'udhaar');
    });

    test('should identify custom category correctly', () {
      expect(ExpenseCategory.custom.isCustom, true);
      expect(ExpenseCategory.food.isCustom, false);
      expect(ExpenseCategory.misc.isCustom, false);
    });

    test('should return selectable categories without custom', () {
      final selectable = ExpenseCategory.selectableCategories;
      expect(selectable.length, 14);
      expect(selectable.contains(ExpenseCategory.custom), false);
      expect(selectable.contains(ExpenseCategory.food), true);
      expect(selectable.contains(ExpenseCategory.misc), true);
    });

    test('should return all categories including custom', () {
      final all = ExpenseCategory.allCategories;
      expect(all.length, 15);
      expect(all.contains(ExpenseCategory.custom), true);
      expect(all.contains(ExpenseCategory.food), true);
    });

    test('should support custom category option', () {
      final custom = ExpenseCategory.custom;
      expect(custom.label, 'Add Custom');
      expect(custom.icon, Icons.add);
      expect(custom.isCustom, true);
    });
  });
}
