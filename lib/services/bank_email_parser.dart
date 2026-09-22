// services/bank_email_parser.dart
import '../models/parsed_email_transaction.dart';
import 'csv_service.dart';

/// Parses bank alert emails into transaction candidates. Deliberately
/// conservative: if the body doesn't match a known template, it returns
/// null rather than guessing, so the caller can flag the message for
/// manual review instead of silently fabricating a transaction.
class BankEmailParser {
  final _categorizer = CsvService();

  /// Sender domains this parser recognizes, matched case-insensitively
  /// against the email's From address. Configurable by the caller since
  /// bank sending domains can change or vary by user (e.g. SBI has used
  /// multiple alert subdomains).
  static const Map<String, String> knownSenderDomains = {
    'canarabank.com': 'Canara Bank',
    'sbi.co.in': 'SBI',
  };

  /// Returns the bank label for a From address, or null if it doesn't
  /// match a known/allowlisted sender domain.
  String? bankForSender(String fromAddress) {
    final lower = fromAddress.toLowerCase();
    for (final entry in knownSenderDomains.entries) {
      final domain = entry.key;
      final atIndex = lower.lastIndexOf('@');
      if (atIndex == -1) continue;
      final hostPart = lower.substring(atIndex + 1);
      if (hostPart == domain || hostPart.endsWith('.$domain')) {
        return entry.value;
      }
    }
    return null;
  }

  ParsedEmailTransaction? parse({
    required String messageKey,
    required String fromAddress,
    required String body,
    required DateTime fallbackDate,
  }) {
    final bank = bankForSender(fromAddress);
    if (bank == null) return null;

    final normalized = body.replaceAll('\r\n', '\n');

    final parsers = <ParsedEmailTransaction? Function()>[
      () => _parseCanara(messageKey, normalized, bank),
      () => _parseSbi(messageKey, normalized, bank),
    ];

    for (final p in parsers) {
      final result = p();
      if (result != null) return result;
    }
    return null;
  }

  // Canara Bank: "An amount of INR 160.00 has been DEBITED on 18/09/26 from
  // your account XXXXX26064 to FUAD HARIS with UPI Ref No.:215137248532.
  // Total Available Balance INR 908.89."
  // (CREDITED variant uses "to your account ... from <payee>".)
  ParsedEmailTransaction? _parseCanara(
    String messageKey,
    String body,
    String bank,
  ) {
    final re = RegExp(
      r'amount of INR\s*([\d,]+\.\d{2})\s*has been (DEBITED|CREDITED)\s*on\s*(\d{2}/\d{2}/\d{2,4})\s*(?:from|to)\s*your account\s*(?:X+)?(\d+)\s*(?:to|from)\s*([A-Za-z .]+?)\s*with UPI Ref No\.?:?\s*(\d+)\.?\s*Total Available Balance INR\s*([\d,]+\.\d{2})',
      caseSensitive: false,
      dotAll: true,
    );
    final match = re.firstMatch(body);
    if (match == null) return null;

    final amount = _parseAmount(match.group(1)!);
    final isDebit = match.group(2)!.toUpperCase() == 'DEBITED';
    final date = _parseShortDate(match.group(3)!);
    final counterparty = match.group(5)!.trim();
    final refNo = match.group(6)!;
    final balance = _parseAmount(match.group(7)!);
    if (date == null || amount == null) return null;

    final description = isDebit
        ? 'Paid to $counterparty (Canara UPI)'
        : 'Received from $counterparty (Canara UPI)';

    return ParsedEmailTransaction(
      messageKey: messageKey,
      date: date,
      description: description,
      referenceNo: refNo,
      debit: isDebit ? amount : 0.0,
      credit: isDebit ? 0.0 : amount,
      balance: balance,
      type: isDebit ? 'debit' : 'credit',
      category: _categorizer.autoCategorize(description),
      sourceBank: bank,
      rawSnippet: _snippet(body),
    );
  }

  // SBI: "Your A/C XXXXX875829 has a debit by transfer of Rs 236.00 on
  // 21/09/26. Avl Bal Rs 54,624.19." or
  // "Rs236.00 debited to your account XXXXX875829 by transfer on
  // 21/09/26. Account balance is Rs54,624.19." (also seen with ₹).
  // Credit variant: "credited to your account" / "credit by transfer".
  ParsedEmailTransaction? _parseSbi(
    String messageKey,
    String body,
    String bank,
  ) {
    final re1 = RegExp(
      r'A/C\s*(?:X+)?(\d+)\s*has a (debit|credit) by transfer of\s*(?:Rs\.?|₹)\s*([\d,]+\.\d{2})\s*on\s*(\d{2}/\d{2}/\d{2,4})\.?\s*Avl\s*Bal\s*(?:Rs\.?|₹)\s*([\d,]+\.\d{2})',
      caseSensitive: false,
      dotAll: true,
    );
    final re2 = RegExp(
      r'(?:Rs\.?|₹)\s*([\d,]+\.\d{2})\s*(debited|credited)\s*to your account\s*(?:X+)?(\d+)\s*by transfer on\s*(\d{2}/\d{2}/\d{2,4})\.?\s*Account balance is\s*(?:Rs\.?|₹)\s*([\d,]+\.\d{2})',
      caseSensitive: false,
      dotAll: true,
    );

    final m1 = re1.firstMatch(body);
    if (m1 != null) {
      final isDebit = m1.group(2)!.toLowerCase() == 'debit';
      final amount = _parseAmount(m1.group(3)!);
      final date = _parseShortDate(m1.group(4)!);
      final balance = _parseAmount(m1.group(5)!);
      if (date == null || amount == null) return null;

      final description = isDebit ? 'SBI account debit (transfer)' : 'SBI account credit (transfer)';
      return ParsedEmailTransaction(
        messageKey: messageKey,
        date: date,
        description: description,
        referenceNo: '',
        debit: isDebit ? amount : 0.0,
        credit: isDebit ? 0.0 : amount,
        balance: balance,
        type: isDebit ? 'debit' : 'credit',
        category: _categorizer.autoCategorize(description),
        sourceBank: bank,
        rawSnippet: _snippet(body),
      );
    }

    final m2 = re2.firstMatch(body);
    if (m2 != null) {
      final isDebit = m2.group(2)!.toLowerCase() == 'debited';
      final amount = _parseAmount(m2.group(1)!);
      final date = _parseShortDate(m2.group(4)!);
      final balance = _parseAmount(m2.group(5)!);
      if (date == null || amount == null) return null;

      final description = isDebit ? 'SBI account debit (transfer)' : 'SBI account credit (transfer)';
      return ParsedEmailTransaction(
        messageKey: messageKey,
        date: date,
        description: description,
        referenceNo: '',
        debit: isDebit ? amount : 0.0,
        credit: isDebit ? 0.0 : amount,
        balance: balance,
        type: isDebit ? 'debit' : 'credit',
        category: _categorizer.autoCategorize(description),
        sourceBank: bank,
        rawSnippet: _snippet(body),
      );
    }

    return null;
  }

  double? _parseAmount(String raw) {
    return double.tryParse(raw.replaceAll(',', ''));
  }

  /// Bank alerts use dd/mm/yy or dd/mm/yyyy. A 2-digit year is treated as
  /// 2000+yy, which is correct for the lifetime this app will plausibly
  /// see use.
  DateTime? _parseShortDate(String raw) {
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _snippet(String body) {
    final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length > 220 ? '${collapsed.substring(0, 220)}…' : collapsed;
  }
}
