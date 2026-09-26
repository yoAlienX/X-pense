// services/mail_sync_service.dart
import 'package:enough_mail/enough_mail.dart';

import '../models/parsed_email_transaction.dart';
import 'bank_email_parser.dart';
import 'storage_service.dart';

class MailAuthException implements Exception {
  final String message;
  MailAuthException(this.message);
  @override
  String toString() => message;
}

/// Connects to the user's mailbox over IMAP (Gmail, via an app password),
/// pulls recent messages from the allowlisted bank sender domains, and
/// parses them into review candidates. Nothing here touches the real
/// transaction list — that only happens when the user confirms a
/// candidate in the review screen.
class MailSyncService {
  MailSyncService({StorageService? storage})
    : _storage = storage ?? StorageService();

  final StorageService _storage;
  final _parser = BankEmailParser();

  static const String _gmailImapHost = 'imap.gmail.com';
  static const int _gmailImapPort = 993;

  /// Verify credentials work by logging in and immediately logging out.
  /// Throws [MailAuthException] with a user-facing message on failure.
  Future<void> verifyCredentials(String email, String appPassword) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(
        _gmailImapHost,
        _gmailImapPort,
        isSecure: true,
      );
      await client.login(email, appPassword);
    } on ImapException catch (e) {
      throw MailAuthException(
        'Could not sign in: ${e.message}. Double-check the address and '
        'that you generated a Gmail "App Password" (not your normal '
        'password) with IMAP access enabled.',
      );
    } catch (e) {
      throw MailAuthException('Could not connect to Gmail: $e');
    } finally {
      try {
        await client.logout();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }

  /// Fetch and parse recent messages from allowlisted bank senders that
  /// haven't already been shown to the user. [lookbackDays] bounds how far
  /// back to search so a first sync doesn't pull someone's entire mail
  /// history.
  Future<MailSyncResult> syncRecentBankEmails({int lookbackDays = 60}) async {
    final email = _storage.getMailAccountEmail();
    final appPassword = await _storage.getMailAppPassword();
    if (email == null || appPassword == null) {
      throw MailAuthException('No email account is connected yet.');
    }

    final alreadyProcessed = _storage.getProcessedMailKeys();
    final client = ImapClient(isLogEnabled: false);
    final candidates = <ParsedEmailTransaction>[];
    final unparsedFromKnownSenders = <String>[];

    try {
      await client.connectToServer(
        _gmailImapHost,
        _gmailImapPort,
        isSecure: true,
      );
      await client.login(email, appPassword);
      final mailbox = await client.selectInbox();
      final uidValidity = mailbox.uidValidity ?? 0;

      final since = DateTime.now().subtract(Duration(days: lookbackDays));
      final sinceStr = _imapDate(since);

      for (final bankDomain in BankEmailParser.knownSenderDomains.keys) {
        final searchResult = await client.searchMessages(
          searchCriteria: 'FROM "$bankDomain" SINCE $sinceStr',
        );
        final sequence = searchResult.matchingSequence;
        if (sequence == null || sequence.isEmpty()) continue;

        final fetchResult = await client.fetchMessageSequence(
          sequence,
          fetchPreference: FetchPreference.full,
        );

        for (final message in fetchResult.messages) {
          final uid = message.uid;
          if (uid == null) continue;
          final key = '$uidValidity:$uid';
          if (alreadyProcessed.contains(key)) continue;

          final fromAddress = message.from?.isNotEmpty == true
              ? message.from!.first.email
              : (message.sender?.email ?? '');
          final body =
              message.decodeTextPlainPart() ??
              _stripHtml(message.decodeTextHtmlPart() ?? '');
          final date = message.decodeDate() ?? DateTime.now();

          final parsed = _parser.parse(
            messageKey: key,
            fromAddress: fromAddress,
            body: body,
            fallbackDate: date,
          );

          if (parsed != null) {
            candidates.add(parsed);
          } else {
            unparsedFromKnownSenders.add(key);
          }
        }
      }
    } on ImapException catch (e) {
      throw MailAuthException('Sync failed: ${e.message}');
    } finally {
      try {
        await client.logout();
      } catch (_) {}
    }

    candidates.sort((a, b) => b.date.compareTo(a.date));
    return MailSyncResult(
      candidates: candidates,
      unparsedCount: unparsedFromKnownSenders.length,
      // Unparsed messages are recorded as processed too, so a template
      // change in one bank email doesn't make every sync re-fetch and
      // re-fail on the same message forever. They're still visible via
      // unparsedCount so the user knows something was skipped.
      allSeenKeys: [
        ...candidates.map((c) => c.messageKey),
        ...unparsedFromKnownSenders,
      ],
    );
  }

  Future<void> markProcessed(Iterable<String> keys) {
    return _storage.addProcessedMailKeys(keys);
  }

  String _imapDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }
}

class MailSyncResult {
  final List<ParsedEmailTransaction> candidates;
  final int unparsedCount;
  final List<String> allSeenKeys;

  MailSyncResult({
    required this.candidates,
    required this.unparsedCount,
    required this.allSeenKeys,
  });
}
