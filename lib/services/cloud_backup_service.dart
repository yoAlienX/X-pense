import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart' as model;
import 'crypto_service.dart';
import 'storage_service.dart';

class CloudBackupService extends ChangeNotifier {
  static final CloudBackupService _instance = CloudBackupService._internal();
  factory CloudBackupService() => _instance;
  CloudBackupService._internal() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  // Gets Telegram Bot token provided by the user in settings
  String get telegramBotToken => StorageService().prefs.getString('telegram_bot_token') ?? '';

  Future<void> setTelegramBotToken(String token) async {
    await StorageService().prefs.setString('telegram_bot_token', token);
    notifyListeners();
  }

  // ==================== Firebase & Google Auth ====================

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Cancelled by user

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      notifyListeners();
      return userCredential.user;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<bool> backupToFirebase(List<model.Transaction> transactions) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      // Instead of writing to Firebase Storage, we push an encrypted payload to Firestore.
      final file = await _generateBackupFile(transactions);
      final fileContent = await file.readAsString();

      final crypto = CryptoService();
      final keyHash = crypto.generateKeyHash();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'backupData': fileContent,
            'encryptionHash': keyHash,
            'lastBackup': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      debugPrint('Firebase Backup Error: $e');
      return false;
    }
  }

  Future<String?> restoreFromFirebase() async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in to Google.');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        throw Exception('No cloud backup found on this account.');
      }

      final data = doc.data();
      if (data == null || !data.containsKey('backupData')) {
        throw Exception('Backup data is empty or corrupted.');
      }

      // Store the hash locally so that if the user restarts the app,
      // the lockscreen knows what key to verify against.
      final hash = data['encryptionHash'] as String?;
      if (hash != null && hash.isNotEmpty) {
        await StorageService().prefs.setString('encryption_hash', hash);
      }

      return data['backupData'] as String;
    } catch (e) {
      debugPrint('Firebase Restore Error: $e');
      throw Exception(e.toString());
    }
  }

  // ==================== Telegram Integration ====================

  Future<String?> fetchTelegramChatId() async {
    final token = telegramBotToken;
    if (token.isEmpty) return null;

    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/getUpdates');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['result'] ?? [];
        if (results.isNotEmpty) {
          // Get the latest message's chat ID
          final latestUpdate = results.last;
          final chatId = latestUpdate['message']['chat']['id'].toString();
          await StorageService().prefs.setString('telegram_chat_id', chatId);
          return chatId;
        }
      }
    } catch (e) {
      debugPrint('Telegram fetch updates error: $e');
    }
    return StorageService().prefs.getString('telegram_chat_id');
  }

  Future<bool> backupToTelegram(List<model.Transaction> transactions) async {
    final token = telegramBotToken;
    if (token.isEmpty) return false;

    final chatId = StorageService().prefs.getString('telegram_chat_id');
    if (chatId == null || chatId.isEmpty) {
      // Try to fetch it again just in case
      final fetchedId = await fetchTelegramChatId();
      if (fetchedId == null || fetchedId.isEmpty) return false;
    }

    final activeChatId = StorageService().prefs.getString('telegram_chat_id')!;

    try {
      final file = await _generateBackupFile(transactions);
      final crypto = CryptoService();
      final keyHash = crypto.generateKeyHash();

      // We append the hash to the caption so it can be extracted later on restore
      final hashTag = keyHash.isNotEmpty ? '\n\nHashID: $keyHash' : '';

      final url = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
      final request = http.MultipartRequest('POST', url)
        ..fields['chat_id'] = activeChatId
        ..fields['caption'] = '🔐 Your X-pense Encrypted Backup\n📅 ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}$hashTag'
        ..files.add(await http.MultipartFile.fromPath('document', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final fileId = data['result']?['document']?['file_id'];
        if (fileId != null) {
          await StorageService().prefs.setString('telegram_latest_file_id', fileId);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Telegram Backup Error: $e');
      return false;
    }
  }

  Future<String?> restoreFromTelegram() async {
    final token = telegramBotToken;
    if (token.isEmpty) throw Exception('No Telegram Bot configured.');

    final fileId = StorageService().prefs.getString('telegram_latest_file_id');
    if (fileId == null || fileId.isEmpty) {
      throw Exception('No previous backup was sent using this app. Please import the CSV file manually.');
    }

    try {
      // Because we cannot fetch the caption via getFile, we must fetch the chat history if we strictly wanted the hash.
      // But for simplicity of 1-click restore, the File payload itself contains the base64 structure.
      // If decryption fails, CsvService catches it.
      // If we *really* wanted to set the hash locally like Google:
      // Since telegram doesn't give us the caption via getFile, we rely strictly on the decryption phase catching bad keys.

      // Step 1: Get the file path from Telegram
      final getFileUrl = Uri.parse('https://api.telegram.org/bot$token/getFile?file_id=$fileId');
      final pathResponse = await http.get(getFileUrl);

      if (pathResponse.statusCode != 200) {
        throw Exception('Failed to locate file on Telegram servers.');
      }

      final pathData = jsonDecode(pathResponse.body);
      final filePath = pathData['result']?['file_path'];
      if (filePath == null) throw Exception('Telegram file path is null.');

      // Step 2: Download the file content
      final downloadUrl = Uri.parse('https://api.telegram.org/file/bot$token/$filePath');
      final downloadResponse = await http.get(downloadUrl);

      if (downloadResponse.statusCode != 200) {
        throw Exception('Failed to download the backup file.');
      }

      return downloadResponse.body;
    } catch (e) {
      debugPrint('Telegram Restore Error: $e');
      throw Exception(e.toString());
    }
  }

  // ==================== Common Backup Generation ====================

  Future<File> _generateBackupFile(List<model.Transaction> transactions) async {
    final List<List<dynamic>> rows = [
      ['Date', 'Description', 'Reference', 'Debit', 'Credit', 'Balance', 'Type', 'Category', 'Account'],
      ...transactions.map((t) => [
            DateFormat('dd-MM-yyyy').format(t.date),
            t.description,
            t.referenceNo,
            t.debit,
            t.credit,
            t.balance,
            t.type,
            t.category,
            t.account,
          ]),
    ];

    String csv = const ListToCsvConverter().convert(rows);
    final crypto = CryptoService();
    String fileExt = 'csv';

    if (crypto.hasSecretKey) {
      csv = crypto.encryptData(csv);
      fileExt = 'enc';
    }

    final directory = await getTemporaryDirectory();
    final fileName = 'expense_tracker_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.$fileExt';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);
    return file;
  }
}
