import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'storage_service.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  String? _secretKey;

  // Retrieve the user's secret key from secure storage / shared prefs
  Future<String?> getSecretKey() async {
    if (_secretKey != null) return _secretKey;
    _secretKey = StorageService().prefs.getString('encryption_key');
    return _secretKey;
  }

  // Set and save the user's secret key
  Future<void> setSecretKey(String key) async {
    _secretKey = key;
    await StorageService().prefs.setString('encryption_key', key);
  }

  bool get hasSecretKey => _secretKey != null && _secretKey!.isNotEmpty;

  // Generate AES Encrypter from secret key
  Encrypter? _getEncrypter() {
    if (_secretKey == null || _secretKey!.isEmpty) return null;

    // Pad or truncate the key to 32 bytes for AES-256
    String formattedKey = _secretKey!;
    if (formattedKey.length < 32) {
      formattedKey = formattedKey.padRight(32, '0');
    } else if (formattedKey.length > 32) {
      formattedKey = formattedKey.substring(0, 32);
    }

    final key = Key.fromUtf8(formattedKey);
    return Encrypter(AES(key, mode: AESMode.gcm));
  }

  // Encrypt string data
  String encryptData(String plainText) {
    final encrypter = _getEncrypter();
    if (encrypter == null) return plainText; // Fallback to plain if no key

    final iv = IV.fromLength(16); // 16-byte IV for AES
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Prepend IV to the base64 encrypted string so we can decrypt later
    return '${iv.base64}:${encrypted.base64}';
  }

  // Decrypt string data
  String decryptData(String encryptedText) {
    if (!encryptedText.contains(':')) return encryptedText; // Probably not encrypted

    final encrypter = _getEncrypter();
    if (encrypter == null) return encryptedText;

    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) return encryptedText;

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      // Decryption failed (wrong key or corrupt data)
      print('Decryption failed: $e');
      return encryptedText;
    }
  }
}
