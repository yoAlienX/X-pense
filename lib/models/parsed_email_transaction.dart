// models/parsed_email_transaction.dart

/// A transaction candidate extracted from a bank alert email. Nothing here
/// is written to the real transaction list until the user reviews and
/// confirms it in the sync screen.
class ParsedEmailTransaction {
  /// Stable identifier for the source email (mailbox UIDVALIDITY:UID),
  /// used to avoid re-importing/re-suggesting the same message.
  final String messageKey;

  final DateTime date;
  final String description;
  final String referenceNo;
  final double debit;
  final double credit;
  final double? balance;
  final String type; // 'debit' or 'credit'
  final String category;
  final String sourceBank;

  /// Short excerpt of the source email, shown so the user can sanity-check
  /// the parse against the original text before importing.
  final String rawSnippet;

  const ParsedEmailTransaction({
    required this.messageKey,
    required this.date,
    required this.description,
    required this.referenceNo,
    required this.debit,
    required this.credit,
    this.balance,
    required this.type,
    required this.category,
    required this.sourceBank,
    required this.rawSnippet,
  });

  ParsedEmailTransaction copyWith({
    DateTime? date,
    String? description,
    String? referenceNo,
    double? debit,
    double? credit,
    double? balance,
    String? type,
    String? category,
  }) {
    return ParsedEmailTransaction(
      messageKey: messageKey,
      date: date ?? this.date,
      description: description ?? this.description,
      referenceNo: referenceNo ?? this.referenceNo,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      category: category ?? this.category,
      sourceBank: sourceBank,
      rawSnippet: rawSnippet,
    );
  }
}
