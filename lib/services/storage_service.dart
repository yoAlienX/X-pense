// services/storage_service.dart
import 'dart:convert';
import 'dart:io';
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
  static const String _passcodeKey = 'passcode';
  static const String _securityQuestionsKey = 'securityQuestions';
  static const String _onboardingCompleteKey = 'onboardingComplete';

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

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
      print('Error saving transactions: $e');
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
      print('Error parsing plain transactions: $e');
      return [];
    }
  }

  /// Clear all transactions
  Future<bool> clearTransactions() async {
    try {
      return await prefs.remove(_transactionsKey);
    } catch (e) {
      print('Error clearing transactions: $e');
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
      print('Error checking resilient onboarding flag: $e');
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
      print('Error saving resilient onboarding flag: $e');
    }

    return prefsResult;
  }

  // ==================== General Utilities ====================

  /// Clear all app data
  Future<bool> clearAllData() async {
    try {
      return await prefs.clear();
    } catch (e) {
      print('Error clearing all data: $e');
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

  /// Get passcode
  String? getPasscode() {
    return prefs.getString(_passcodeKey);
  }

  /// Save passcode
  Future<bool> savePasscode(String passcode) async {
    return await prefs.setString(_passcodeKey, passcode);
  }

  /// Remove stored passcode
  Future<bool> clearPasscode() async {
    return await prefs.remove(_passcodeKey);
  }

  /// Get security questions
  Map<String, String> getSecurityQuestions() {
    final jsonString = prefs.getString(_securityQuestionsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return {'q1': '', 'a1': '', 'q2': '', 'a2': ''};
    }
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return jsonData.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print('Error loading security questions: $e');
      return {'q1': '', 'a1': '', 'q2': '', 'a2': ''};
    }
  }

  /// Save security questions
  Future<bool> saveSecurityQuestions(Map<String, String> questions) async {
    try {
      final jsonString = jsonEncode(questions);
      return await prefs.setString(_securityQuestionsKey, jsonString);
    } catch (e) {
      print('Error saving security questions: $e');
      return false;
    }
  }

  /// Remove stored security questions
  Future<bool> clearSecurityQuestions() async {
    return await prefs.remove(_securityQuestionsKey);
  }
}
