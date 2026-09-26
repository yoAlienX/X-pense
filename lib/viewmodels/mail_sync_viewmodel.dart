// viewmodels/mail_sync_viewmodel.dart
import 'package:flutter/material.dart';

import '../models/parsed_email_transaction.dart';
import '../services/mail_sync_service.dart';
import '../services/storage_service.dart';

class MailSyncViewModel extends ChangeNotifier {
  MailSyncViewModel({StorageService? storage, MailSyncService? mailService})
    : _storage = storage ?? StorageService(),
      _mailService = mailService ?? MailSyncService(storage: storage);

  final StorageService _storage;
  final MailSyncService _mailService;

  bool _isConnecting = false;
  bool _isSyncing = false;
  String? _error;
  int _lastUnparsedCount = 0;

  List<ParsedEmailTransaction> _candidates = [];
  final Set<String> _selectedKeys = {};

  bool get isConnecting => _isConnecting;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  int get lastUnparsedCount => _lastUnparsedCount;
  bool get isConnected => _storage.hasMailAccountConfigured;
  String? get connectedEmail => _storage.getMailAccountEmail();

  List<ParsedEmailTransaction> get candidates => List.unmodifiable(_candidates);
  bool isSelected(String key) => _selectedKeys.contains(key);
  int get selectedCount => _selectedKeys.length;

  /// Validate the credentials against Gmail, then store them (app password
  /// goes to secure storage, never SharedPreferences).
  Future<bool> connect(String email, String appPassword) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      await _mailService.verifyCredentials(email.trim(), appPassword);
      await _storage.saveMailAccountEmail(email.trim());
      await _storage.saveMailAppPassword(appPassword);
      return true;
    } on MailAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Could not connect: $e';
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _storage.clearMailAccount();
    _candidates = [];
    _selectedKeys.clear();
    notifyListeners();
  }

  Future<void> sync() async {
    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _mailService.syncRecentBankEmails();
      _candidates = result.candidates;
      _lastUnparsedCount = result.unparsedCount;
      // Select everything by default; the user deselects what they don't
      // want rather than having to opt in to each one individually.
      _selectedKeys
        ..clear()
        ..addAll(_candidates.map((c) => c.messageKey));
      // Record every message we looked at (matched or not) so re-syncing
      // doesn't keep re-surfacing/re-failing on the same mail. Candidates
      // are only marked as reviewed for real once the user confirms or
      // explicitly dismisses them — see markSeenWithoutImporting.
    } on MailAuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Sync failed: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void toggleSelected(String key) {
    if (_selectedKeys.contains(key)) {
      _selectedKeys.remove(key);
    } else {
      _selectedKeys.add(key);
    }
    notifyListeners();
  }

  void updateCandidate(String key, ParsedEmailTransaction updated) {
    final index = _candidates.indexWhere((c) => c.messageKey == key);
    if (index == -1) return;
    _candidates[index] = updated;
    notifyListeners();
  }

  List<ParsedEmailTransaction> get selectedCandidates =>
      _candidates.where((c) => _selectedKeys.contains(c.messageKey)).toList();

  /// After the caller has written the selected candidates into the real
  /// transaction list, mark every candidate we showed (selected or not) as
  /// processed so they don't resurface on the next sync.
  Future<void> markThisBatchReviewed() async {
    final keys = _candidates.map((c) => c.messageKey);
    await _mailService.markProcessed(keys);
    _candidates = [];
    _selectedKeys.clear();
    notifyListeners();
  }
}
