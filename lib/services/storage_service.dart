// services/storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import 'crypto_service.dart';

class StorageService {
  static const String _transactionsKey = 'transactions';
  static const String _themeKey = 'isDarkMode';
  static const String _balanceVisibilityKey = 'balanceVisible';
  static const String _categoriesKey = 'categories';
  static const String _defaultCategoryKey = 'defaultCategory';
  static const String _accountsKey = 'accounts';
  static const String _showTotalBalanceKey = 'showTotalBalance';
  static const String _passcodeEnabledKey = 'passcodeEnabled';
  static const String _biometricEnabledKey = 'biometricEnabled';
  static const String _faceAuthEnabledKey = 'faceAuthEnabled';
  static const String _securityQuestionsKey = 'securityQuestions';
  static const String _onboardingCompleteKey = 'onboardingComplete';

  // Secure-storage keys. These never touch plaintext SharedPreferences,
  // and hold only salted hashes (never the raw passcode/answers).
  static const String _passcodeHashKey = 'secure_passcode_hash';
  static const String _passcodeSaltKey = 'secure_passcode_salt';
  static const String _answerOneHashKey = 'secure_answer_one_hash';
  static const String _answerOneSaltKey = 'secure_answer_one_salt';
  static const String _answerTwoHashKey = 'secure_answer_two_hash';
  static const String _answerTwoSaltKey = 'secure_answer_two_salt';

  // Lockout bookkeeping for brute-force protection on passcode/answer entry.
  static const String _failedAttemptsKey = 'lock_failed_attempts';
  static const String _lockoutUntilKey = 'lock_lockout_until_ms';

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Initialize storage
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  void _logError(String message, Object e) {
    // Avoid leaking user data / stack traces into release logcat.
    if (kDebugMode) {
      debugPrint('$message: $e');
    }
  }

  // ==================== Transaction Storage ====================

  /// Save transactions to storage
  Future<bool> saveTransactions(List<Transaction> transactions) async {
    try {
      final jsonData = transactions.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(jsonData);

      final crypto = CryptoService();
      final encryptedData = crypto.hasSecretKey ? crypto.encryptData(jsonString) : jsonString;

      return await prefs.setString(_transactionsKey, encryptedData);
    } catch (e) {
      _logError('Error saving transactions', e);
      return false;
    }
  }

  /// Load transactions from storage
  Future<List<Transaction>> loadTransactions() async {
    final storedData = prefs.getString(_transactionsKey);
    if (storedData == null || storedData.isEmpty) {
      return [];
    }

    final crypto = CryptoService();

    // Check if the payload looks encrypted (base64 with an IV colon delimiter and no JSON brackets)
    if (storedData.contains(':') && !storedData.startsWith('[')) {
      if (!crypto.hasSecretKey) {
        throw const FormatException('needs_decryption');
      }

      final decryptedString = crypto.decryptData(storedData);

      // If decryption failed and returned the original string, or garbage
      if (decryptedString.contains(':') && !decryptedString.startsWith('[')) {
        throw const FormatException('needs_decryption');
      }

      try {
        final List<dynamic> jsonData = jsonDecode(decryptedString);
        return jsonData.map((json) => Transaction.fromJson(json)).toList();
      } catch (e) {
        throw const FormatException('needs_decryption');
      }
    }

    // Unencrypted Payload
    try {
      final List<dynamic> jsonData = jsonDecode(storedData);
      return jsonData.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      _logError('Error loading transactions', e);
      return [];
    }
  }

  /// Clear all transactions
  Future<bool> clearTransactions() async {
    try {
      return await prefs.remove(_transactionsKey);
    } catch (e) {
      _logError('Error clearing transactions', e);
      return false;
    }
  }

  // ==================== Theme Storage ====================

  /// Get theme preference
  bool getThemePreference() {
    return prefs.getBool(_themeKey) ?? false;
  }

  /// Save theme preference
  Future<bool> saveThemePreference(bool isDarkMode) async {
    return await prefs.setBool(_themeKey, isDarkMode);
  }

  // ==================== Balance Visibility ====================

  /// Get balance visibility preference
  bool getBalanceVisibility() {
    return prefs.getBool(_balanceVisibilityKey) ?? false;
  }

  /// Save balance visibility preference
  Future<bool> saveBalanceVisibility(bool isVisible) async {
    return await prefs.setBool(_balanceVisibilityKey, isVisible);
  }

  // ==================== Category Storage ====================

  /// Get custom category list
  List<String>? getCategories() {
    return prefs.getStringList(_categoriesKey);
  }

  /// Save custom category list
  Future<bool> saveCategories(List<String> categories) async {
    return await prefs.setStringList(_categoriesKey, categories);
  }

  /// Get default category
  String? getDefaultCategory() {
    return prefs.getString(_defaultCategoryKey);
  }

  /// Save default category
  Future<bool> saveDefaultCategory(String category) async {
    return await prefs.setString(_defaultCategoryKey, category);
  }

  // ==================== Account Storage ====================

  /// Get account list
  List<String>? getAccounts() {
    return prefs.getStringList(_accountsKey);
  }

  /// Save account list
  Future<bool> saveAccounts(List<String> accounts) async {
    return await prefs.setStringList(_accountsKey, accounts);
  }

  /// Get show total balance preference
  bool getShowTotalBalance() {
    return prefs.getBool(_showTotalBalanceKey) ?? false;
  }

  /// Save show total balance preference
  Future<bool> saveShowTotalBalance(bool showTotal) async {
    return await prefs.setBool(_showTotalBalanceKey, showTotal);
  }

  // ==================== Onboarding Storage ====================

  /// Check if onboarding is completed
  Future<bool> hasCompletedOnboarding() async {
    // Check SharedPreferences first
    final bool prefsCompleted = prefs.getBool(_onboardingCompleteKey) ?? false;
    if (prefsCompleted) return true;

    // Fallback: Check local document directory for resilient flag file
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/.onboarding_flag');
      if (await file.exists()) {
        // Sync the preference back so it's correct next time
        await saveOnboardingComplete();
        return true;
      }
    } catch (e) {
      _logError('Error checking resilient onboarding flag', e);
    }

    return false;
  }

  /// Mark onboarding as completed
  Future<bool> saveOnboardingComplete() async {
    bool prefsResult = await prefs.setBool(_onboardingCompleteKey, true);

    // Save resilient flag to file system to survive shared preferences clearing
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/.onboarding_flag');
      await file.writeAsString('1');
    } catch (e) {
      _logError('Error saving resilient onboarding flag', e);
    }

    return prefsResult;
  }

  // ==================== General Utilities ====================

  /// Clear all app data
  Future<bool> clearAllData() async {
    try {
      final ok = await prefs.clear();
      await _secure.deleteAll();
      return ok;
    } catch (e) {
      _logError('Error clearing all data', e);
      return false;
    }
  }

  /// Get all stored keys (for debugging)
  Set<String> getAllKeys() {
    return prefs.getKeys();
  }

  // ==================== App Lock Storage ====================

  /// Get passcode enabled state
  bool getPasscodeEnabled() {
    return prefs.getBool(_passcodeEnabledKey) ?? false;
  }

  /// Save passcode enabled state
  Future<bool> savePasscodeEnabled(bool enabled) async {
    return await prefs.setBool(_passcodeEnabledKey, enabled);
  }

  /// Get biometric unlock enabled state
  bool getBiometricUnlockEnabled() {
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Save biometric unlock enabled state
  Future<bool> saveBiometricUnlockEnabled(bool enabled) async {
    return await prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Get face authentication enabled state
  bool getFaceAuthenticationEnabled() {
    return prefs.getBool(_faceAuthEnabledKey) ?? false;
  }

  /// Save face authentication enabled state
  Future<bool> saveFaceAuthenticationEnabled(bool enabled) async {
    return await prefs.setBool(_faceAuthEnabledKey, enabled);
  }

  // -------------------- Salted-hash helpers --------------------
  // The passcode and security-question answers are never written to disk in
  // plaintext. Each secret gets its own random salt; we persist only
  // sha256(salt + secret) in the platform keystore/keychain-backed secure
  // storage. Verification re-hashes the candidate and compares digests.

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String value, String salt) {
    return sha256.convert(utf8.encode('$salt:$value')).toString();
  }

  Future<void> _storeSecret({
    required String value,
    required String hashKey,
    required String saltKey,
  }) async {
    final salt = _generateSalt();
    final hash = _hash(value, salt);
    await _secure.write(key: saltKey, value: salt);
    await _secure.write(key: hashKey, value: hash);
  }

  Future<bool> _verifySecret({
    required String candidate,
    required String hashKey,
    required String saltKey,
  }) async {
    final salt = await _secure.read(key: saltKey);
    final storedHash = await _secure.read(key: hashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(candidate, salt) == storedHash;
  }

  /// Save passcode as a salted hash (never stored in plaintext).
  Future<void> savePasscode(String passcode) async {
    await _storeSecret(
      value: passcode,
      hashKey: _passcodeHashKey,
      saltKey: _passcodeSaltKey,
    );
  }

  /// Whether a passcode has been configured.
  Future<bool> hasPasscode() async {
    return (await _secure.read(key: _passcodeHashKey)) != null;
  }

  /// Verify a candidate passcode against the stored salted hash.
  Future<bool> verifyPasscode(String candidate) async {
    return _verifySecret(
      candidate: candidate,
      hashKey: _passcodeHashKey,
      saltKey: _passcodeSaltKey,
    );
  }

  /// Remove stored passcode hash/salt
  Future<void> clearPasscode() async {
    await _secure.delete(key: _passcodeHashKey);
    await _secure.delete(key: _passcodeSaltKey);
  }

  /// Get security questions (question text only — never the answers).
  Map<String, String> getSecurityQuestions() {
    final jsonString = prefs.getString(_securityQuestionsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return {'q1': '', 'q2': ''};
    }
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return jsonData.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      _logError('Error loading security questions', e);
      return {'q1': '', 'q2': ''};
    }
  }

  /// Save security question text (q1/q2) and salted-hash the answers
  /// (a1/a2) into secure storage.
  Future<void> saveSecurityQuestions(Map<String, String> questions) async {
    try {
      final jsonString = jsonEncode({
        'q1': questions['q1'] ?? '',
        'q2': questions['q2'] ?? '',
      });
      await prefs.setString(_securityQuestionsKey, jsonString);

      await _storeSecret(
        value: questions['a1'] ?? '',
        hashKey: _answerOneHashKey,
        saltKey: _answerOneSaltKey,
      );
      await _storeSecret(
        value: questions['a2'] ?? '',
        hashKey: _answerTwoHashKey,
        saltKey: _answerTwoSaltKey,
      );
    } catch (e) {
      _logError('Error saving security questions', e);
    }
  }

  /// Verify both security answers (case-insensitive, trimmed by the caller)
  /// against their stored salted hashes.
  Future<bool> verifySecurityAnswers({
    required String answerOne,
    required String answerTwo,
  }) async {
    final oneOk = await _verifySecret(
      candidate: answerOne,
      hashKey: _answerOneHashKey,
      saltKey: _answerOneSaltKey,
    );
    final twoOk = await _verifySecret(
      candidate: answerTwo,
      hashKey: _answerTwoHashKey,
      saltKey: _answerTwoSaltKey,
    );
    return oneOk && twoOk;
  }

  /// Remove stored security questions and answer hashes
  Future<void> clearSecurityQuestions() async {
    await prefs.remove(_securityQuestionsKey);
    await _secure.delete(key: _answerOneHashKey);
    await _secure.delete(key: _answerOneSaltKey);
    await _secure.delete(key: _answerTwoHashKey);
    await _secure.delete(key: _answerTwoSaltKey);
  }

  // -------------------- Brute-force lockout --------------------

  int getFailedAttempts() {
    return prefs.getInt(_failedAttemptsKey) ?? 0;
  }

  Future<void> setFailedAttempts(int count) async {
    await prefs.setInt(_failedAttemptsKey, count);
  }

  /// Epoch-ms timestamp until which further attempts are blocked, or null.
  int? getLockoutUntilMs() {
    return prefs.getInt(_lockoutUntilKey);
  }

  Future<void> setLockoutUntilMs(int? epochMs) async {
    if (epochMs == null) {
      await prefs.remove(_lockoutUntilKey);
    } else {
      await prefs.setInt(_lockoutUntilKey, epochMs);
    }
  }

  Future<void> clearLockoutState() async {
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockoutUntilKey);
  }
}
