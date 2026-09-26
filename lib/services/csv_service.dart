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
      allowedExtensions: ['csv', 'enc'],
    );
    if (result == null) return null;

    final file = File(result.files.single.path!);
    final input = file.readAsStringSync();
    return importFromData(input);
  }

  /// Parse a CSV string directly into transactions. Used by cloud restores.
  Future<List<Transaction>?> importFromData(String input) async {
    input = input.trim();

    // Decrypt if it's an encrypted backup
    final crypto = CryptoService();
    // Encrypted payloads are base64 strings separated by a colon
    if (input.contains(':') && !input.contains(',')) {
      if (!crypto.hasSecretKey) {
        throw Exception('Backup is encrypted, but no secret key is configured in Security Settings.');
      }
      try {
        input = crypto.decryptData(input);
        if (input.contains(':') && !input.contains(',')) {
          // If it still doesn't look like CSV after decryption, key was likely wrong but decrypt didn't throw
          throw Exception('Decryption failed. Invalid Secret Key.');
        }
      } catch (e) {
        throw Exception('Decryption failed. Invalid Secret Key.');
      }
    }

    final List<List<dynamic>> csvData =
        const CsvToListConverter().convert(input);

    final List<Transaction> parsed = [];
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      // A well-formed data row always has at least 7 columns (Date,
      // Description, Reference, Debit, Credit, Balance, Type). Anything
      // shorter is malformed/truncated input — skip it rather than let a
      // bounds error surface with a misleading stack trace.
      if (row.length < 7) continue;
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
            _sanitizeForCsv(t.description),
            _sanitizeForCsv(t.referenceNo),
            t.debit,
            t.credit,
            t.balance,
            t.type,
            _sanitizeForCsv(t.category),
            _sanitizeForCsv(t.account),
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

  /// Neutralize CSV/formula injection. Spreadsheet apps (Excel, Sheets,
  /// LibreOffice) treat a cell starting with =, +, -, @, tab or carriage
  /// return as a formula. A transaction description imported from an
  /// untrusted bank statement or edited by hand could contain one, and it
  /// would silently execute when the exported/backup CSV is later opened.
  /// Prefixing such cells with a leading apostrophe forces plain-text
  /// interpretation while keeping the visible value unchanged.
  String _sanitizeForCsv(String value) {
    if (value.isEmpty) return value;
    const dangerousPrefixes = ['=', '+', '-', '@', '\t', '\r'];
    if (dangerousPrefixes.any((p) => value.startsWith(p))) {
      return "'$value";
    }
    return value;
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
