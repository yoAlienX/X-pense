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

  // Brute-force protection: after this many consecutive wrong entries the
  // user is locked out for an escalating cooldown before trying again.
  static const int _maxAttemptsBeforeLockout = 5;
  static const Duration _baseLockoutDuration = Duration(seconds: 30);

  bool _isInitializing = true;
  bool _isLocked = false;
  bool _passcodeEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _lastBiometricError = '';

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  String _questionOne = '';
  String _questionTwo = '';

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

  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  Duration get lockoutRemaining {
    if (!isLockedOut) return Duration.zero;
    return _lockoutUntil!.difference(DateTime.now());
  }

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
    final hasPasscode = await _storage.hasPasscode();

    final questions = _storage.getSecurityQuestions();
    _questionOne = questions['q1'] ?? '';
    _questionTwo = questions['q2'] ?? '';

    _restoreLockoutState();

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
      if (!hasPasscode) {
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

  void _restoreLockoutState() {
    _failedAttempts = _storage.getFailedAttempts();
    final until = _storage.getLockoutUntilMs();
    _lockoutUntil = until == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(until);
    if (_lockoutUntil != null && !DateTime.now().isBefore(_lockoutUntil!)) {
      // Cooldown already elapsed since the last session.
      _lockoutUntil = null;
    }
  }

  Future<void> _registerFailedAttempt() async {
    _failedAttempts += 1;
    await _storage.setFailedAttempts(_failedAttempts);

    if (_failedAttempts >= _maxAttemptsBeforeLockout) {
      // Escalate the cooldown for every block of failures beyond the
      // threshold (30s, 60s, 90s, ...) instead of a fixed short delay.
      final multiplier = 1 + (_failedAttempts - _maxAttemptsBeforeLockout);
      final duration = _baseLockoutDuration * multiplier;
      _lockoutUntil = DateTime.now().add(duration);
      await _storage.setLockoutUntilMs(_lockoutUntil!.millisecondsSinceEpoch);
    }
  }

  Future<void> _registerSuccessfulAttempt() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    await _storage.clearLockoutState();
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
    _questionOne = questionOne.trim();
    _questionTwo = questionTwo.trim();

    _passcodeEnabled = true;
    _isLocked = false;

    await _storage.savePasscode(passcode);
    await _storage.savePasscodeEnabled(true);
    await _storage.saveSecurityQuestions({
      'q1': _questionOne,
      'a1': answerOne.trim().toLowerCase(),
      'q2': _questionTwo,
      'a2': answerTwo.trim().toLowerCase(),
    });
    await _registerSuccessfulAttempt();

    notifyListeners();
  }

  Future<void> disablePasscode() async {
    _questionOne = '';
    _questionTwo = '';

    _passcodeEnabled = false;
    _isLocked = false;
    _biometricEnabled = false;

    await _storage.savePasscodeEnabled(false);
    await _storage.clearPasscode();
    await _storage.clearSecurityQuestions();
    await _storage.saveBiometricUnlockEnabled(false);
    await _registerSuccessfulAttempt();

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

    if (isLockedOut) {
      return false;
    }

    final ok = await _storage.verifyPasscode(value);
    if (ok) {
      _isLocked = false;
      await CryptoService().loadKeyFromSecureStorage();
      await _registerSuccessfulAttempt();
      notifyListeners();
      return true;
    }

    await _registerFailedAttempt();
    notifyListeners();
    return false;
  }

  Future<bool> unlockWithBiometric() async {
    if (!_passcodeEnabled || !_biometricAvailable || !_biometricEnabled) {
      return false;
    }
    if (isLockedOut) {
      _lastBiometricError = 'Too many attempts. Try again later.';
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
        await _registerSuccessfulAttempt();
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

  Future<bool> verifySecurityAnswers({
    required String answerOne,
    required String answerTwo,
  }) async {
    if (isLockedOut) return false;

    final ok = await _storage.verifySecurityAnswers(
      answerOne: answerOne.trim().toLowerCase(),
      answerTwo: answerTwo.trim().toLowerCase(),
    );

    if (!ok) {
      await _registerFailedAttempt();
      notifyListeners();
    }

    return ok;
  }

  Future<bool> resetPasscodeWithSecurityAnswers({
    required String answerOne,
    required String answerTwo,
    required String newPasscode,
  }) async {
    final verified = await verifySecurityAnswers(
      answerOne: answerOne,
      answerTwo: answerTwo,
    );
    if (!verified) {
      return false;
    }

    await _storage.savePasscode(newPasscode);
    await _registerSuccessfulAttempt();
    _isLocked = false;
    notifyListeners();
    return true;
  }
}
