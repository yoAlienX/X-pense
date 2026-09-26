import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_service.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  String? _secretKey;
  final _secureStorage = const FlutterSecureStorage();

  // Set the secret key into memory.
  // We also save it to secure storage so it can be auto-loaded later.
  Future<void> setSecretKey(String key) async {
    _secretKey = key;
    await _secureStorage.write(key: 'aes_secret_key', value: key);
  }

  // Try loading from secure storage
  Future<bool> loadKeyFromSecureStorage() async {
    final key = await _secureStorage.read(key: 'aes_secret_key');
    if (key != null && key.isNotEmpty) {
      _secretKey = key;
      return true;
    }
    return false;
  }

  // Clear from memory and secure storage
  Future<void> clearSecretKey() async {
    _secretKey = null;
    await _secureStorage.delete(key: 'aes_secret_key');
  }

  bool get hasSecretKey => _secretKey != null && _secretKey!.isNotEmpty;

  // Handles 30-day expiration of the locally cached hash
  Future<void> checkAndEnforceHashExpiration() async {
    final prefs = StorageService().prefs;
    final timestamp = prefs.getInt('encryption_hash_date');
    if (timestamp != null) {
      final savedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(savedDate).inDays >= 30) {
        // Expired after 30 days. Force user to re-enter it.
        await prefs.remove('encryption_hash');
        await prefs.remove('encryption_hash_date');
        await clearSecretKey();
      }
    }
  }

  // Saves the hash locally and updates the timestamp
  Future<void> persistHashLocally() async {
    if (_secretKey == null || _secretKey!.isEmpty) return;
    final hash = generateKeyHash();
    final prefs = StorageService().prefs;
    await prefs.setString('encryption_hash', hash);
    await prefs.setInt('encryption_hash_date', DateTime.now().millisecondsSinceEpoch);
  }

  // Generate SHA-256 hash of the secret key for cloud verification
  String generateKeyHash() {
    if (_secretKey == null || _secretKey!.isEmpty) return '';
    final bytes = utf8.encode(_secretKey!);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate SHA-256 hash from a specific string
  String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

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
