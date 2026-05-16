// services/csv_service.dart
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import 'crypto_service.dart';

class CsvService {
  // ==================== Import ====================

  /// Pick and parse a CSV file. Returns parsed transactions or null if cancelled.
  Future<List<Transaction>?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return null;

    final file = File(result.files.single.path!);
    String input = file.readAsStringSync();

    // Decrypt if it's an encrypted backup
    final crypto = CryptoService();
    if (crypto.hasSecretKey && input.contains(':')) {
      input = crypto.decryptData(input);
    }

    final List<List<dynamic>> csvData =
        const CsvToListConverter().convert(input);

    final List<Transaction> parsed = [];
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      try {
        final date = DateFormat('dd-MM-yyyy').parse(row[0].toString());
        final debit =
            row[3].toString().isEmpty ? 0.0 : double.parse(row[3].toString());
        final credit =
            row[4].toString().isEmpty ? 0.0 : double.parse(row[4].toString());
        final description = row[1].toString();

        // Prefer the CSV-provided category (index 7 in exported files).
        // If missing/blank, keep compatibility by falling back to heuristics.
        String? csvCategory;
        if (row.length > 7) {
          final rawCategory = row[7].toString().trim();
          if (rawCategory.isNotEmpty) {
            csvCategory = rawCategory;
          }
        }
        final category = csvCategory ?? autoCategorize(description);

        String account = 'Canara Bank';
        if (row.length > 8) {
          final rawAccount = row[8].toString().trim();
          if (rawAccount.isNotEmpty) {
            account = rawAccount;
          }
        }

        parsed.add(Transaction(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          date: date,
          description: description,
          referenceNo: row[2].toString(),
          debit: debit,
          credit: credit,
          balance: double.tryParse(row[5].toString()) ?? 0.0,
          type: row[6].toString(),
          category: category,
          account: account,
        ));
      } catch (e) {
        // Skip malformed rows
      }
    }
    return parsed;
  }

  // ==================== Export ====================

  /// Export the given transaction list as CSV and share it.
  Future<void> exportAndShare(
    List<Transaction> transactions, {
    String subject = 'Expense Tracker Export',
    String? text,
    bool isBackup = false,
  }) async {
    final List<List<dynamic>> rows = [
      ['Date', 'Description', 'Reference', 'Debit', 'Credit', 'Balance', 'Type', 'Category', 'Account'],
      ...transactions.map((t) => [
            DateFormat('dd-MM-yyyy').format(t.date),
            t.description,
            t.referenceNo,
            t.debit,
            t.credit,
            t.balance,
            t.type,
            t.category,
            t.account,
          ]),
    ];

    String csv = const ListToCsvConverter().convert(rows);
    final crypto = CryptoService();
    String fileExt = 'csv';

    if (isBackup && crypto.hasSecretKey) {
      csv = crypto.encryptData(csv);
      fileExt = 'enc';
    }

    final directory = await getTemporaryDirectory();
    final prefix = isBackup ? 'expense_tracker_backup' : 'expense_export';
    final fileName =
        '${prefix}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.$fileExt';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: text ?? 'Exported ${transactions.length} transactions',
    );
  }

  // ==================== Auto-categorization ====================

  /// Heuristically categorize a transaction based on its description.
  String autoCategorize(String description) {
    final lower = description.toLowerCase();

    if (lower.contains('zomato') ||
        lower.contains('swiggy') ||
        lower.contains('restaurant') ||
        lower.contains('food')) {
      return 'Food & Dining';
    } else if (lower.contains('kerala st') ||
        lower.contains('bus') ||
        lower.contains('petrol') ||
        lower.contains('uber') ||
        lower.contains('ola')) {
      return 'Transportation';
    } else if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('shop')) {
      return 'Shopping';
    } else if (lower.contains('jio') ||
        lower.contains('electricity') ||
        lower.contains('water') ||
        lower.contains('sms charges')) {
      return 'Bills & Utilities';
    } else if (lower.contains('movie') || lower.contains('game')) {
      return 'Entertainment';
    } else if (lower.contains('hospital') ||
        lower.contains('medical') ||
        lower.contains('pharmacy') ||
        lower.contains('bismi med')) {
      return 'Health';
    } else if (lower.contains('university') ||
        lower.contains('college') ||
        lower.contains('school') ||
        lower.contains('udemy')) {
      return 'Education';
    } else if (lower.contains('atm cash')) {
      return 'ATM Withdrawal';
    } else if (lower.contains('transfer') ||
        lower.contains('upi cr') ||
        lower.contains('upi dr')) {
      return 'Transfer/UPI';
    } else if (lower.contains('salary') || lower.contains('interest')) {
      return 'Salary/Income';
    }
    return 'Uncategorized';
  }
}
