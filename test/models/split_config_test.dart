import 'package:flutter_test/flutter_test.dart';
import 'package:roomie_spend/models/split_config.dart';

void main() {
  group('EqualSplit', () {
    test('calculates equal amounts correctly for even split', () {
      final split = EqualSplit(['user1', 'user2', 'user3']);
      final amounts = split.calculateAmounts(300.0);

      expect(amounts['user1'], 100.0);
      expect(amounts['user2'], 100.0);
      expect(amounts['user3'], 100.0);
    });

    test('handles rounding by adjusting last member', () {
      // Requirements 11.5, 11.6: Handle rounding adjustment
      final split = EqualSplit(['user1', 'user2', 'user3']);
      final amounts = split.calculateAmounts(100.0);

      // Sum should exactly equal total
      final sum = amounts.values.fold(0.0, (a, b) => a + b);
      expect((sum - 100.0).abs(), lessThan(0.00001));
    });

    test('validates correctly with valid data', () {
      final split = EqualSplit(['user1', 'user2']);
      expect(split.isValid(100.0), true);
    });

    test('validates correctly with empty members', () {
      final split = EqualSplit([]);
      expect(split.isValid(100.0), false);
    });

    test('validates correctly with zero amount', () {
      final split = EqualSplit(['user1', 'user2']);
      expect(split.isValid(0.0), false);
    });

    test('serializes to map correctly', () {
      final split = EqualSplit(['user1', 'user2', 'user3']);
      final map = split.toMap();

      expect(map['type'], 'equal');
      expect(map['memberIds'], ['user1', 'user2', 'user3']);
    });

    test('deserializes from map correctly', () {
      final map = {
        'type': 'equal',
        'memberIds': ['user1', 'user2', 'user3'],
      };
      final split = EqualSplit.fromMap(map);

      expect(split.memberIds, ['user1', 'user2', 'user3']);
    });

    test('calculates amounts for single member', () {
      final split = EqualSplit(['user1']);
      final amounts = split.calculateAmounts(150.0);

      expect(amounts['user1'], 150.0);
    });

    test('calculates amounts for many members', () {
      final split = EqualSplit(['user1', 'user2', 'user3', 'user4', 'user5']);
      final amounts = split.calculateAmounts(500.0);

      // Sum should exactly equal total
      final sum = amounts.values.fold(0.0, (a, b) => a + b);
      expect((sum - 500.0).abs(), lessThan(0.00001));
    });
  });

  group('UnequalSplitByAmount', () {
    test('calculates amounts correctly', () {
      // Requirement 12.1: Unequal split by amount
      final split = UnequalSplitByAmount({
        'user1': 150.0,
        'user2': 100.0,
        'user3': 50.0,
      });
      final amounts = split.calculateAmounts(300.0);

      expect(amounts['user1'], 150.0);
      expect(amounts['user2'], 100.0);
      expect(amounts['user3'], 50.0);
    });

    test('validates correctly when amounts equal total', () {
      // Requirements 12.5, 12.6: Split validation
      final split = UnequalSplitByAmount({
        'user1': 150.0,
        'user2': 150.0,
      });
      expect(split.isValid(300.0), true);
    });

    test('validates correctly when amounts do not equal total', () {
      final split = UnequalSplitByAmount({
        'user1': 150.0,
        'user2': 100.0,
      });
      expect(split.isValid(300.0), false);
    });

    test('validates correctly with empty amounts', () {
      final split = UnequalSplitByAmount({});
      expect(split.isValid(100.0), false);
    });

    test('handles floating point tolerance in validation', () {
      final split = UnequalSplitByAmount({
        'user1': 33.33,
        'user2': 33.33,
        'user3': 33.34,
      });
      expect(split.isValid(100.0), true);
    });

    test('serializes to map correctly', () {
      final split = UnequalSplitByAmount({
        'user1': 150.0,
        'user2': 100.0,
      });
      final map = split.toMap();

      expect(map['type'], 'unequalAmount');
      expect(map['amounts'], {'user1': 150.0, 'user2': 100.0});
    });

    test('deserializes from map correctly', () {
      final map = {
        'type': 'unequalAmount',
        'amounts': {'user1': 150.0, 'user2': 100.0},
      };
      final split = UnequalSplitByAmount.fromMap(map);

      expect(split.amounts['user1'], 150.0);
      expect(split.amounts['user2'], 100.0);
    });
  });

  group('UnequalSplitByShares', () {
    test('calculates proportional amounts correctly', () {
      // Requirements 13.1, 13.2: Share-based proportional calculation
      final split = UnequalSplitByShares({
        'user1': 2,
        'user2': 1,
        'user3': 1,
      });
      final amounts = split.calculateAmounts(400.0);

      // Total shares = 4, so user1 gets 2/4 = 50%, user2 and user3 get 1/4 = 25% each
      expect(amounts['user1'], 200.0);
      expect(amounts['user2'], 100.0);
      expect(amounts['user3'], 100.0);
    });

    test('handles rounding by adjusting last member', () {
      final split = UnequalSplitByShares({
        'user1': 1,
        'user2': 1,
        'user3': 1,
      });
      final amounts = split.calculateAmounts(100.0);

      // Sum should exactly equal total
      final sum = amounts.values.fold(0.0, (a, b) => a + b);
      expect((sum - 100.0).abs(), lessThan(0.00001));
    });

    test('validates correctly with valid data', () {
      final split = UnequalSplitByShares({
        'user1': 2,
        'user2': 1,
      });
      expect(split.isValid(100.0), true);
    });

    test('validates correctly with empty shares', () {
      final split = UnequalSplitByShares({});
      expect(split.isValid(100.0), false);
    });

    test('validates correctly with zero total shares', () {
      final split = UnequalSplitByShares({
        'user1': 0,
        'user2': 0,
      });
      expect(split.isValid(100.0), false);
    });

    test('calculates with unequal share distribution', () {
      final split = UnequalSplitByShares({
        'user1': 5,
        'user2': 3,
        'user3': 2,
      });
      final amounts = split.calculateAmounts(1000.0);

      // Total shares = 10
      expect(amounts['user1'], 500.0); // 5/10
      expect(amounts['user2'], 300.0); // 3/10
      expect(amounts['user3'], 200.0); // 2/10
    });

    test('serializes to map correctly', () {
      final split = UnequalSplitByShares({
        'user1': 2,
        'user2': 1,
      });
      final map = split.toMap();

      expect(map['type'], 'unequalShares');
      expect(map['shares'], {'user1': 2, 'user2': 1});
    });

    test('deserializes from map correctly', () {
      final map = {
        'type': 'unequalShares',
        'shares': {'user1': 2, 'user2': 1},
      };
      final split = UnequalSplitByShares.fromMap(map);

      expect(split.shares['user1'], 2);
      expect(split.shares['user2'], 1);
    });
  });

  group('ItemWiseSplit', () {
    test('calculates amounts correctly for single item', () {
      // Requirement 14.1: Item-wise split
      final item = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1', 'user2'],
      );
      final split = ItemWiseSplit([item]);
      final amounts = split.calculateAmounts(20.0);

      // Pizza costs 20.0, split between user1 and user2
      expect(amounts['user1'], 10.0);
      expect(amounts['user2'], 10.0);
    });

    test('calculates amounts correctly for multiple items', () {
      final item1 = SplitItem(
        description: 'Pizza',
        quantity: 1,
        pricePerUnit: 20.0,
        memberIds: ['user1', 'user2'],
      );
      final item2 = SplitItem(
        description: 'Drink',
        quantity: 2,
        pricePerUnit: 5.0,
        memberIds: ['user1'],
      );
      final split = ItemWiseSplit([item1, item2]);
      final amounts = split.calculateAmounts(30.0);

      // user1: 10.0 (pizza) + 10.0 (drinks) = 20.0
      // user2: 10.0 (pizza)
      expect(amounts['user1'], 20.0);
      expect(amounts['user2'], 10.0);
    });

    test('handles items with single member', () {
      final item = SplitItem(
        description: 'Coffee',
        quantity: 1,
        pricePerUnit: 5.0,
        memberIds: ['user1'],
      );
      final split = ItemWiseSplit([item]);
      final amounts = split.calculateAmounts(5.0);

      expect(amounts['user1'], 5.0);
    });

    test('handles items with multiple quantities', () {
      final item = SplitItem(
        description: 'Burger',
        quantity: 3,
        pricePerUnit: 10.0,
        memberIds: ['user1', 'user2', 'user3'],
      );
      final split = ItemWiseSplit([item]);
      final amounts = split.calculateAmounts(30.0);

      // Total 30.0, split among 3 members
      expect(amounts['user1'], 10.0);
      expect(amounts['user2'], 10.0);
      expect(amounts['user3'], 10.0);
    });

    test('validates correctly when totals match', () {
      // Requirements 14.10, 14.11: Item-wise validation
      final item = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1', 'user2'],
      );
      final split = ItemWiseSplit([item]);
      expect(split.isValid(20.0), true);
    });

    test('validates correctly when totals do not match', () {
      final item = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1', 'user2'],
      );
      final split = ItemWiseSplit([item]);
      expect(split.isValid(25.0), false);
    });

    test('validates correctly with empty items', () {
      final split = ItemWiseSplit([]);
      expect(split.isValid(100.0), false);
    });

    test('validates correctly when item has no members', () {
      final item = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: [],
      );
      final split = ItemWiseSplit([item]);
      expect(split.isValid(20.0), false);
    });

    test('serializes to map correctly', () {
      final item = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1', 'user2'],
      );
      final split = ItemWiseSplit([item]);
      final map = split.toMap();

      expect(map['type'], 'itemWise');
      expect(map['items'].length, 1);
      expect(map['items'][0]['description'], 'Pizza');
    });

    test('deserializes from map correctly', () {
      final map = {
        'type': 'itemWise',
        'items': [
          {
            'description': 'Pizza',
            'quantity': 2,
            'pricePerUnit': 10.0,
            'memberIds': ['user1', 'user2'],
          }
        ],
      };
      final split = ItemWiseSplit.fromMap(map);

      expect(split.items.length, 1);
      expect(split.items[0].description, 'Pizza');
      expect(split.items[0].quantity, 2);
      expect(split.items[0].pricePerUnit, 10.0);
    });
  });

  group('SplitItem', () {
    test('calculates total price correctly', () {
      final item = SplitItem(
        description: 'Pizza',
        quantity: 3,
        pricePerUnit: 12.50,
        memberIds: ['user1', 'user2'],
      );

      expect(item.totalPrice, 37.50);
    });

    test('serializes to map correctly', () {
      final item = SplitItem(
        description: 'Coffee',
        quantity: 2,
        pricePerUnit: 5.0,
        memberIds: ['user1'],
      );
      final map = item.toMap();

      expect(map['description'], 'Coffee');
      expect(map['quantity'], 2);
      expect(map['pricePerUnit'], 5.0);
      expect(map['memberIds'], ['user1']);
    });

    test('deserializes from map correctly', () {
      final map = {
        'description': 'Coffee',
        'quantity': 2,
        'pricePerUnit': 5.0,
        'memberIds': ['user1'],
      };
      final item = SplitItem.fromMap(map);

      expect(item.description, 'Coffee');
      expect(item.quantity, 2);
      expect(item.pricePerUnit, 5.0);
      expect(item.memberIds, ['user1']);
    });

    test('copyWith creates correct copy', () {
      final item = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1'],
      );
      final copied = item.copyWith(
        quantity: 3,
        memberIds: ['user1', 'user2'],
      );

      expect(copied.description, 'Pizza');
      expect(copied.quantity, 3);
      expect(copied.pricePerUnit, 10.0);
      expect(copied.memberIds, ['user1', 'user2']);
    });

    test('equality comparison works correctly', () {
      final item1 = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1', 'user2'],
      );
      final item2 = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1', 'user2'],
      );

      expect(item1 == item2, true);
    });

    test('inequality comparison works correctly', () {
      final item1 = SplitItem(
        description: 'Pizza',
        quantity: 2,
        pricePerUnit: 10.0,
        memberIds: ['user1'],
      );
      final item2 = SplitItem(
        description: 'Pizza',
        quantity: 3,
        pricePerUnit: 10.0,
        memberIds: ['user1'],
      );

      expect(item1 == item2, false);
    });
  });

  group('SplitConfig.fromMap', () {
    test('deserializes EqualSplit correctly', () {
      final map = {
        'type': 'equal',
        'memberIds': ['user1', 'user2'],
      };
      final split = SplitConfig.fromMap(map);

      expect(split, isA<EqualSplit>());
      expect((split as EqualSplit).memberIds, ['user1', 'user2']);
    });

    test('deserializes UnequalSplitByAmount correctly', () {
      final map = {
        'type': 'unequalAmount',
        'amounts': {'user1': 60.0, 'user2': 40.0},
      };
      final split = SplitConfig.fromMap(map);

      expect(split, isA<UnequalSplitByAmount>());
      expect((split as UnequalSplitByAmount).amounts['user1'], 60.0);
    });

    test('deserializes UnequalSplitByShares correctly', () {
      final map = {
        'type': 'unequalShares',
        'shares': {'user1': 2, 'user2': 1},
      };
      final split = SplitConfig.fromMap(map);

      expect(split, isA<UnequalSplitByShares>());
      expect((split as UnequalSplitByShares).shares['user1'], 2);
    });

    test('deserializes ItemWiseSplit correctly', () {
      final map = {
        'type': 'itemWise',
        'items': [
          {
            'description': 'Pizza',
            'quantity': 1,
            'pricePerUnit': 20.0,
            'memberIds': ['user1', 'user2'],
          }
        ],
      };
      final split = SplitConfig.fromMap(map);

      expect(split, isA<ItemWiseSplit>());
      expect((split as ItemWiseSplit).items.length, 1);
    });

    test('throws error for unknown type', () {
      final map = {
        'type': 'unknown',
      };

      expect(
        () => SplitConfig.fromMap(map),
        throwsArgumentError,
      );
    });
  });
}
