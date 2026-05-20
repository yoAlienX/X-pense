import 'package:flutter_test/flutter_test.dart';
import 'package:x_pense/viewmodels/app_lock_viewmodel.dart';
import 'package:x_pense/services/storage_service.dart';
import 'package:x_pense/models/transaction.dart' as transaction_model;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock StorageService logic inline
class MockStorageService implements StorageService {
  Map<String, String> _securityQuestions = {'q1': '', 'a1': '', 'q2': '', 'a2': ''};
  bool _passcodeEnabled = false;
  bool _biometricEnabled = false;
  String? _passcode = '';

  @override
  bool getPasscodeEnabled() => _passcodeEnabled;
  @override
  Future<bool> savePasscodeEnabled(bool enabled) async {
    _passcodeEnabled = enabled;
    return true;
  }

  @override
  bool getBiometricUnlockEnabled() => _biometricEnabled;
  @override
  Future<bool> saveBiometricUnlockEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    return true;
  }

  @override
  String? getPasscode() => _passcode;
  @override
  Future<bool> savePasscode(String passcode) async {
    _passcode = passcode;
    return true;
  }
  @override
  Future<bool> clearPasscode() async {
    _passcode = null;
    return true;
  }

  @override
  Map<String, String> getSecurityQuestions() => _securityQuestions;
  @override
  Future<bool> saveSecurityQuestions(Map<String, String> questions) async {
    _securityQuestions = questions;
    return true;
  }
  @override
  Future<bool> clearSecurityQuestions() async {
    _securityQuestions = {'q1': '', 'a1': '', 'q2': '', 'a2': ''};
    return true;
  }

  // Not needed for this test, returning defaults
  @override
  Future<void> init() async {}
  @override
  SharedPreferences get prefs => throw UnimplementedError();
  @override
  Future<bool> saveTransactions(List<transaction_model.Transaction> transactions) async => true;
  @override
  Future<List<transaction_model.Transaction>> loadTransactions() async => [];
  @override
  Future<bool> clearTransactions() async => true;
  @override
  bool getThemePreference() => false;
  @override
  Future<bool> saveThemePreference(bool isDarkMode) async => true;
  @override
  bool getBalanceVisibility() => false;
  @override
  Future<bool> saveBalanceVisibility(bool isVisible) async => true;
  @override
  List<String>? getCategories() => null;
  @override
  Future<bool> saveCategories(List<String> categories) async => true;
  @override
  String? getDefaultCategory() => null;
  @override
  Future<bool> saveDefaultCategory(String category) async => true;
  @override
  Future<bool> clearAllData() async => true;
  @override
  Set<String> getAllKeys() => {};
  @override
  bool getFaceAuthenticationEnabled() => false;
  @override
  Future<bool> saveFaceAuthenticationEnabled(bool enabled) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  group('AppLockViewModel Security Answers Hashing', () {
    late AppLockViewModel viewModel;
    late MockStorageService mockStorage;

    setUp(() {
      mockStorage = MockStorageService();
      viewModel = AppLockViewModel(storage: mockStorage);
    });

    test('configurePasscode correctly hashes answers', () async {
      await viewModel.configurePasscode(
        passcode: '1234',
        questionOne: 'Q1',
        answerOne: 'plaintext1',
        questionTwo: 'Q2',
        answerTwo: 'plaintext2',
      );

      final storedQuestions = mockStorage.getSecurityQuestions();
      expect(storedQuestions['a1'], hashString('plaintext1'));
      expect(storedQuestions['a2'], hashString('plaintext2'));

      // verifySecurityAnswers works correctly with correct answers
      expect(viewModel.verifySecurityAnswers(answerOne: 'plaintext1', answerTwo: 'plaintext2'), isTrue);

      // verifySecurityAnswers fails with incorrect answers
      expect(viewModel.verifySecurityAnswers(answerOne: 'wrong', answerTwo: 'plaintext2'), isFalse);
    });

    test('initialize migrates plaintext answers to hashed versions', () async {
      // Simulate stored plaintext answers
      await mockStorage.saveSecurityQuestions({
        'q1': 'Q1',
        'a1': 'plaintext1', // not a hash
        'q2': 'Q2',
        'a2': 'plaintext2', // not a hash
      });

      // trigger initialization which should perform migration
      await viewModel.initialize();

      // Ensure storage was updated to hashes
      final storedQuestions = mockStorage.getSecurityQuestions();
      expect(storedQuestions['a1'], hashString('plaintext1'));
      expect(storedQuestions['a2'], hashString('plaintext2'));

      // Also ensure we can correctly verify answers against them
      expect(viewModel.verifySecurityAnswers(answerOne: 'plaintext1', answerTwo: 'plaintext2'), isTrue);
    });

    test('initialize does not re-hash already hashed answers', () async {
      // Simulate already hashed answers
      final h1 = hashString('plaintext1');
      final h2 = hashString('plaintext2');

      await mockStorage.saveSecurityQuestions({
        'q1': 'Q1',
        'a1': h1,
        'q2': 'Q2',
        'a2': h2,
      });

      await viewModel.initialize();

      final storedQuestions = mockStorage.getSecurityQuestions();
      expect(storedQuestions['a1'], h1);
      expect(storedQuestions['a2'], h2);

      expect(viewModel.verifySecurityAnswers(answerOne: 'plaintext1', answerTwo: 'plaintext2'), isTrue);
    });
  });
}
