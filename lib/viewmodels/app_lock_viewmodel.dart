import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';
import '../services/crypto_service.dart';

class AppLockViewModel extends ChangeNotifier {
  AppLockViewModel({StorageService? storage})
    : _storage = storage ?? StorageService();

  final StorageService _storage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const List<String> securityQuestionOptions = [
    'What is your childhood nickname?',
    'What is your favorite teacher\'s name?',
    'What is your first school name?',
    'What was your first pet\'s name?',
    'What city were you born in?',
  ];

  bool _isInitializing = true;
  bool _isLocked = false;
  bool _passcodeEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _lastBiometricError = '';
  String _passcode = '';

  String _questionOne = '';
  String _answerOne = '';
  String _questionTwo = '';
  String _answerTwo = '';

  bool get isInitializing => _isInitializing;
  bool get isLocked => _isLocked;
  bool get passcodeEnabled => _passcodeEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricAvailable => _biometricAvailable;
  String get lastBiometricError => _lastBiometricError;
  bool get canUseBiometric =>
      _biometricAvailable && _biometricEnabled && _passcodeEnabled;
  bool get shouldRequireLock => _passcodeEnabled;

  String get questionOne => _questionOne;
  String get questionTwo => _questionTwo;

  Future<void> _evaluateBiometricAvailability() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      _biometricAvailable = isSupported && canCheck;
      _lastBiometricError = '';
    } catch (e) {
      _biometricAvailable = false;
      _lastBiometricError = 'Biometrics unavailable: $e';
    }
  }

  Future<bool> authenticate(Future<bool> Function() onFallbackToPasscode) async {
    if (!passcodeEnabled) return true;

    if (biometricEnabled && biometricAvailable) {
      try {
        final success = await _localAuth.authenticate(
          localizedReason: 'Authenticate to reveal balances',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (success) {
            await CryptoService().loadKeyFromSecureStorage();
            return true;
        }
      } catch (e) {
        debugPrint('Authentication error: $e');
      }
    }

    return await onFallbackToPasscode();
  }

  Future<void> refreshBiometricAvailability() async {
    final oldAvailable = _biometricAvailable;
    final oldError = _lastBiometricError;
    final oldEnabled = _biometricEnabled;

    await _evaluateBiometricAvailability();

    if (oldAvailable != _biometricAvailable ||
        oldError != _lastBiometricError ||
        oldEnabled != _biometricEnabled) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    _passcodeEnabled = _storage.getPasscodeEnabled();
    _biometricEnabled = _storage.getBiometricUnlockEnabled();
    _passcode = _storage.getPasscode() ?? '';

    final questions = _storage.getSecurityQuestions();
    _questionOne = questions['q1'] ?? '';
    _answerOne = questions['a1'] ?? '';
    _questionTwo = questions['q2'] ?? '';
    _answerTwo = questions['a2'] ?? '';

    await _evaluateBiometricAvailability();

    if (!_passcodeEnabled && _biometricEnabled) {
      _biometricEnabled = false;
      await _storage.saveBiometricUnlockEnabled(false);
    }

    if (!_passcodeEnabled) {
      _isLocked = false;
      _biometricEnabled = false;
      await _storage.saveBiometricUnlockEnabled(false);
      // No app lock -> eagerly attempt to load AES key
      await CryptoService().loadKeyFromSecureStorage();
    } else {
      _isLocked = true;
      if (_passcode.isEmpty) {
        _passcodeEnabled = false;
        _biometricEnabled = false;
        _isLocked = false;
        await _storage.savePasscodeEnabled(false);
        await _storage.saveBiometricUnlockEnabled(false);
        await CryptoService().loadKeyFromSecureStorage();
      }
    }

    _isInitializing = false;
    notifyListeners();
  }

  void enforceLockOnStartup() {
    if (shouldRequireLock) {
      _isLocked = true;
      notifyListeners();
    }
  }

  Future<void> configurePasscode({
    required String passcode,
    required String questionOne,
    required String answerOne,
    required String questionTwo,
    required String answerTwo,
  }) async {
    _passcode = passcode;
    _questionOne = questionOne.trim();
    _answerOne = answerOne.trim().toLowerCase();
    _questionTwo = questionTwo.trim();
    _answerTwo = answerTwo.trim().toLowerCase();

    _passcodeEnabled = true;
    _isLocked = false;

    await _storage.savePasscode(passcode);
    await _storage.savePasscodeEnabled(true);
    await _storage.saveSecurityQuestions({
      'q1': _questionOne,
      'a1': _answerOne,
      'q2': _questionTwo,
      'a2': _answerTwo,
    });

    notifyListeners();
  }

  Future<void> disablePasscode() async {
    _passcode = '';
    _questionOne = '';
    _answerOne = '';
    _questionTwo = '';
    _answerTwo = '';

    _passcodeEnabled = false;
    _isLocked = false;
    _biometricEnabled = false;

    await _storage.savePasscodeEnabled(false);
    await _storage.clearPasscode();
    await _storage.clearSecurityQuestions();
    await _storage.saveBiometricUnlockEnabled(false);

    notifyListeners();
  }

  void lockApp() {
    if (!_passcodeEnabled) return;
    if (_isLocked) return;
    _isLocked = true;
    notifyListeners();
  }

  Future<bool> unlockWithPasscode(String value) async {
    if (!_passcodeEnabled) {
      _isLocked = false;
      notifyListeners();
      await CryptoService().loadKeyFromSecureStorage();
      return true;
    }

    if (value == _passcode) {
      _isLocked = false;
      await CryptoService().loadKeyFromSecureStorage();
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> unlockWithBiometric() async {
    if (!_passcodeEnabled || !_biometricAvailable || !_biometricEnabled) {
      return false;
    }

    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock X-pense',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );

      _lastBiometricError = '';

      if (ok) {
        _isLocked = false;
        await CryptoService().loadKeyFromSecureStorage();
        notifyListeners();
      }

      return ok;
    } on PlatformException catch (e) {
      if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        _biometricAvailable = false;
        notifyListeners();
        Future<void>.delayed(const Duration(seconds: 31), () async {
          await refreshBiometricAvailability();
        });
      }
      _lastBiometricError = _mapBiometricError(e.code, e.message);
      return false;
    } catch (e) {
      _lastBiometricError = 'Biometric error: $e';
      return false;
    }
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      if (!_passcodeEnabled || !_biometricAvailable) {
        if (!_passcodeEnabled) {
          _lastBiometricError = 'Set a passcode before enabling biometrics.';
        } else if (!_biometricAvailable) {
          _lastBiometricError =
              'Biometric authentication is not available on this device.';
        }
        return false;
      }

      bool allowed;
      try {
        allowed = await _localAuth.authenticate(
          localizedReason: 'Confirm biometric unlock setup',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: false,
          ),
        );
      } on PlatformException catch (e) {
        _lastBiometricError = _mapBiometricError(e.code, e.message);
        return false;
      } catch (e) {
        _lastBiometricError = 'Biometric setup failed: $e';
        return false;
      }

      if (!allowed) {
        if (_lastBiometricError.isEmpty) {
          _lastBiometricError =
              'Biometric verification was cancelled or failed.';
        }
        return false;
      }

      _lastBiometricError = '';
    }

    _biometricEnabled = enabled;
    await _storage.saveBiometricUnlockEnabled(enabled);
    notifyListeners();
    return true;
  }

  String _mapBiometricError(String code, String? message) {
    switch (code) {
      case 'NotAvailable':
        return 'Biometric hardware is not available right now.';
      case 'NotEnrolled':
        return 'No biometrics enrolled on this device.';
      case 'PasscodeNotSet':
        return 'Device screen lock is not set. Set a PIN/pattern first.';
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return 'Biometrics temporarily locked. Use device PIN and try again.';
      case 'no_fragment_activity':
        return 'Android host activity must be FlutterFragmentActivity. Rebuild and reinstall the app.';
      default:
        return message == null || message.isEmpty
            ? 'Biometric authentication failed.'
            : message;
    }
  }

  bool verifySecurityAnswers({
    required String answerOne,
    required String answerTwo,
  }) {
    final one = answerOne.trim().toLowerCase();
    final two = answerTwo.trim().toLowerCase();
    return one == _answerOne && two == _answerTwo;
  }

  Future<bool> resetPasscodeWithSecurityAnswers({
    required String answerOne,
    required String answerTwo,
    required String newPasscode,
  }) async {
    final verified = verifySecurityAnswers(
      answerOne: answerOne,
      answerTwo: answerTwo,
    );
    if (!verified) {
      return false;
    }

    _passcode = newPasscode;
    await _storage.savePasscode(newPasscode);
    _isLocked = false;
    notifyListeners();
    return true;
  }
}
