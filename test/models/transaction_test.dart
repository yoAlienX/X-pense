import 'package:flutter_test/flutter_test.dart';
import 'package:x_pense/models/transaction.dart';

void main() {
  group('Transaction JSON serialization', () {
    final date = DateTime(2023, 10, 25, 12, 30);
    final transaction = Transaction(
      id: 'tx_123',
      date: date,
      description: 'Groceries',
      referenceNo: 'ref_456',
      debit: 50.5,
      credit: 0.0,
      balance: 100.0,
      type: 'debit',
      category: 'Food',
    );

    test('toJson returns a valid map', () {
      final json = transaction.toJson();

      expect(json, {
        'id': 'tx_123',
        'date': date.toIso8601String(),
        'description': 'Groceries',
        'referenceNo': 'ref_456',
        'debit': 50.5,
        'credit': 0.0,
        'balance': 100.0,
        'type': 'debit',
        'category': 'Food',
      });
    });

    test('fromJson parses a valid map', () {
      final json = {
        'id': 'tx_123',
        'date': date.toIso8601String(),
        'description': 'Groceries',
        'referenceNo': 'ref_456',
        'debit': 50.5,
        'credit': 0.0,
        'balance': 100.0,
        'type': 'debit',
        'category': 'Food',
      };

      final parsedTransaction = Transaction.fromJson(json);

      expect(parsedTransaction.id, 'tx_123');
      expect(parsedTransaction.date, date);
      expect(parsedTransaction.description, 'Groceries');
      expect(parsedTransaction.referenceNo, 'ref_456');
      expect(parsedTransaction.debit, 50.5);
      expect(parsedTransaction.credit, 0.0);
      expect(parsedTransaction.balance, 100.0);
      expect(parsedTransaction.type, 'debit');
      expect(parsedTransaction.category, 'Food');
    });

    test('fromJson handles integer values for double fields', () {
      final json = {
        'id': 'tx_123',
        'date': date.toIso8601String(),
        'description': 'Groceries',
        'referenceNo': 'ref_456',
        'debit': 50,    // Integer instead of double
        'credit': 0,    // Integer instead of double
        'balance': 100, // Integer instead of double
        'type': 'debit',
        'category': 'Food',
      };

      final parsedTransaction = Transaction.fromJson(json);

      expect(parsedTransaction.debit, 50.0);
      expect(parsedTransaction.credit, 0.0);
      expect(parsedTransaction.balance, 100.0);
    });

    test('fromJson falls back to Uncategorized if category is null', () {
      final json = {
        'id': 'tx_123',
        'date': date.toIso8601String(),
        'description': 'Groceries',
        'referenceNo': 'ref_456',
        'debit': 50.5,
        'credit': 0.0,
        'balance': 100.0,
        'type': 'debit',
        // 'category' is intentionally omitted/null
      };

      final parsedTransaction = Transaction.fromJson(json);

      expect(parsedTransaction.category, 'Uncategorized');
    });
  });
}
