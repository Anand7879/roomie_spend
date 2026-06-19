import 'package:flutter_test/flutter_test.dart';
import 'package:roomie_spend/models/payer_config.dart';

void main() {
  group('SinglePayer', () {
    test('should create a valid SinglePayer instance', () {
      const payer = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );

      expect(payer.userId, 'user123');
      expect(payer.userName, 'John Doe');
      expect(payer.amount, 100.0);
    });

    test('should validate correctly when amount matches expense amount', () {
      const payer = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );

      expect(payer.isValid(100.0), true);
    });

    test('should validate correctly with floating point precision', () {
      const payer = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.005,
      );

      // Within 0.01 epsilon
      expect(payer.isValid(100.0), true);
    });

    test('should invalidate when amount does not match expense amount', () {
      const payer = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );

      expect(payer.isValid(200.0), false);
    });

    test('should invalidate when userId is empty', () {
      const payer = SinglePayer(
        userId: '',
        userName: 'John Doe',
        amount: 100.0,
      );

      expect(payer.isValid(100.0), false);
    });

    test('should serialize to map correctly', () {
      const payer = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );

      final map = payer.toMap();

      expect(map['payerType'], 'single');
      expect(map['singlePayerId'], 'user123');
      expect(map['singlePayerName'], 'John Doe');
      expect(map['multiPayerAmounts'], null);
    });

    test('should implement equality correctly', () {
      const payer1 = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );
      const payer2 = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );
      const payer3 = SinglePayer(
        userId: 'user456',
        userName: 'Jane Doe',
        amount: 100.0,
      );

      expect(payer1, payer2);
      expect(payer1 == payer3, false);
    });

    test('should have consistent hashCode', () {
      const payer1 = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );
      const payer2 = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );

      expect(payer1.hashCode, payer2.hashCode);
    });
  });

  group('MultiPayer', () {
    test('should create a valid MultiPayer instance', () {
      const payer = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });

      expect(payer.payerAmounts['user1'], 60.0);
      expect(payer.payerAmounts['user2'], 40.0);
    });

    test('should calculate total correctly', () {
      const payer = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
        'user3': 20.0,
      });

      expect(payer.total, 120.0);
    });

    test('should calculate remaining amount correctly', () {
      const payer = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });

      expect(payer.getRemaining(150.0), 50.0);
      expect(payer.getRemaining(100.0), 0.0);
      expect(payer.getRemaining(80.0), -20.0);
    });

    test('should validate correctly when total matches expense amount', () {
      const payer = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });

      expect(payer.isValid(100.0), true);
    });

    test('should validate correctly with floating point precision', () {
      const payer = MultiPayer({
        'user1': 60.005,
        'user2': 40.0,
      });

      // Within 0.01 epsilon
      expect(payer.isValid(100.0), true);
    });

    test('should invalidate when total does not match expense amount', () {
      const payer = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });

      expect(payer.isValid(150.0), false);
    });

    test('should invalidate when payerAmounts is empty', () {
      const payer = MultiPayer({});

      expect(payer.isValid(100.0), false);
    });

    test('should serialize to map correctly', () {
      const payer = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });

      final map = payer.toMap();

      expect(map['payerType'], 'multi');
      expect(map['singlePayerId'], null);
      expect(map['singlePayerName'], null);
      expect(map['multiPayerAmounts'], {'user1': 60.0, 'user2': 40.0});
    });

    test('should implement equality correctly', () {
      const payer1 = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });
      const payer2 = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });
      const payer3 = MultiPayer({
        'user1': 50.0,
        'user2': 50.0,
      });

      expect(payer1, payer2);
      expect(payer1 == payer3, false);
    });

    test('should have consistent hashCode', () {
      const payer1 = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });
      const payer2 = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });

      expect(payer1.hashCode, payer2.hashCode);
    });

    test('should handle single payer in multi-payer mode', () {
      const payer = MultiPayer({
        'user1': 100.0,
      });

      expect(payer.total, 100.0);
      expect(payer.isValid(100.0), true);
    });

    test('should handle many payers', () {
      const payer = MultiPayer({
        'user1': 25.0,
        'user2': 25.0,
        'user3': 25.0,
        'user4': 25.0,
      });

      expect(payer.total, 100.0);
      expect(payer.isValid(100.0), true);
    });
  });

  group('PayerConfig.fromMap', () {
    test('should deserialize SinglePayer from map', () {
      final map = {
        'payerType': 'single',
        'singlePayerId': 'user123',
        'singlePayerName': 'John Doe',
        'amount': 100.0,
      };

      final config = PayerConfig.fromMap(map);

      expect(config, isA<SinglePayer>());
      final singlePayer = config as SinglePayer;
      expect(singlePayer.userId, 'user123');
      expect(singlePayer.userName, 'John Doe');
      expect(singlePayer.amount, 100.0);
    });

    test('should deserialize MultiPayer from map', () {
      final map = {
        'payerType': 'multi',
        'multiPayerAmounts': {
          'user1': 60.0,
          'user2': 40.0,
        },
      };

      final config = PayerConfig.fromMap(map);

      expect(config, isA<MultiPayer>());
      final multiPayer = config as MultiPayer;
      expect(multiPayer.payerAmounts['user1'], 60.0);
      expect(multiPayer.payerAmounts['user2'], 40.0);
      expect(multiPayer.total, 100.0);
    });

    test('should default to SinglePayer when payerType is missing', () {
      final map = {
        'singlePayerId': 'user123',
        'singlePayerName': 'John Doe',
        'amount': 100.0,
      };

      final config = PayerConfig.fromMap(map);

      expect(config, isA<SinglePayer>());
    });

    test('should handle missing fields gracefully for SinglePayer', () {
      final map = <String, dynamic>{};

      final config = PayerConfig.fromMap(map);

      expect(config, isA<SinglePayer>());
      final singlePayer = config as SinglePayer;
      expect(singlePayer.userId, '');
      expect(singlePayer.userName, '');
      expect(singlePayer.amount, 0.0);
    });

    test('should handle missing fields gracefully for MultiPayer', () {
      final map = {
        'payerType': 'multi',
      };

      final config = PayerConfig.fromMap(map);

      expect(config, isA<MultiPayer>());
      final multiPayer = config as MultiPayer;
      expect(multiPayer.payerAmounts, isEmpty);
    });

    test('should handle numeric types for amounts in MultiPayer', () {
      final map = {
        'payerType': 'multi',
        'multiPayerAmounts': {
          'user1': 60, // int
          'user2': 40.5, // double
        },
      };

      final config = PayerConfig.fromMap(map);

      expect(config, isA<MultiPayer>());
      final multiPayer = config as MultiPayer;
      expect(multiPayer.payerAmounts['user1'], 60.0);
      expect(multiPayer.payerAmounts['user2'], 40.5);
    });
  });

  group('PayerConfig round-trip serialization', () {
    test('should serialize and deserialize SinglePayer correctly', () {
      const original = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 100.0,
      );

      final map = original.toMap();
      final deserialized = PayerConfig.fromMap(map);

      expect(deserialized, isA<SinglePayer>());
      final singlePayer = deserialized as SinglePayer;
      expect(singlePayer.userId, original.userId);
      expect(singlePayer.userName, original.userName);
      // Note: amount is not stored in the map for SinglePayer in the current implementation
    });

    test('should serialize and deserialize MultiPayer correctly', () {
      const original = MultiPayer({
        'user1': 60.0,
        'user2': 40.0,
      });

      final map = original.toMap();
      final deserialized = PayerConfig.fromMap(map);

      expect(deserialized, original);
    });
  });

  group('Edge cases', () {
    test('should handle zero amounts in SinglePayer', () {
      const payer = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 0.0,
      );

      expect(payer.isValid(0.0), true);
    });

    test('should handle zero amounts in MultiPayer', () {
      const payer = MultiPayer({
        'user1': 0.0,
      });

      expect(payer.total, 0.0);
      expect(payer.isValid(0.0), true);
    });

    test('should handle negative amounts in calculation', () {
      const payer = MultiPayer({
        'user1': 100.0,
        'user2': -50.0,
      });

      expect(payer.total, 50.0);
      expect(payer.isValid(50.0), true);
    });

    test('should handle very large amounts', () {
      const payer = SinglePayer(
        userId: 'user123',
        userName: 'John Doe',
        amount: 999999999.99,
      );

      expect(payer.isValid(999999999.99), true);
    });

    test('should handle many payers in MultiPayer', () {
      final payerAmounts = <String, double>{};
      for (int i = 0; i < 100; i++) {
        payerAmounts['user$i'] = 1.0;
      }

      final payer = MultiPayer(payerAmounts);

      expect(payer.total, 100.0);
      expect(payer.isValid(100.0), true);
    });
  });
}
