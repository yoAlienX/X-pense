// models/transaction.dart
import 'package:intl/intl.dart';

class Transaction {
  final String id;
  final DateTime date;
  final String description;
  final String referenceNo;
  final double debit;  // Money going out (expenses)
  final double credit; // Money coming in (income)
  double balance;      // Running balance after this transaction
  final String type;   // 'debit' or 'credit'
  String category;

  Transaction({
    required this.id,
    required this.date,
    required this.description,
    required this.referenceNo,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.type,
    this.category = 'Uncategorized',
  });

  // Convenience getters
  bool get isExpense => debit > 0;
  bool get isIncome => credit > 0;
  double get amount => isExpense ? debit : credit;

  // Formatted date string
  String get formattedDate => DateFormat('dd MMM yyyy').format(date);
  String get formattedTime => DateFormat('hh:mm a').format(date);
  
  // Month and year for filtering
  int get month => date.month;
  int get year => date.year;
  String get monthName => DateFormat('MMM').format(date);

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'description': description,
    'referenceNo': referenceNo,
    'debit': debit,
    'credit': credit,
    'balance': balance,
    'type': type,
    'category': category,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    date: DateTime.parse(json['date']),
    description: json['description'],
    referenceNo: json['referenceNo'],
    debit: (json['debit'] as num).toDouble(),
    credit: (json['credit'] as num).toDouble(),
    balance: (json['balance'] as num).toDouble(),
    type: json['type'],
    category: json['category'] ?? 'Uncategorized',
  );

  // Create a copy with updated fields
  Transaction copyWith({
    String? id,
    DateTime? date,
    String? description,
    String? referenceNo,
    double? debit,
    double? credit,
    double? balance,
    String? type,
    String? category,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      referenceNo: referenceNo ?? this.referenceNo,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      category: category ?? this.category,
    );
  }

  @override
  String toString() => 'Transaction(id: $id, date: $formattedDate, amount: ₹${amount.toStringAsFixed(2)}, type: $type, category: $category)';
}
