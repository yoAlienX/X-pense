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

class CloudBackupService {
  static final CloudBackupService _instance = CloudBackupService._internal();
  factory CloudBackupService() => _instance;
  CloudBackupService._internal();

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  // Gets Telegram Bot token provided by the user in settings
  String get _telegramBotToken => StorageService().prefs.getString('telegram_bot_token') ?? '';

  Future<void> setTelegramBotToken(String token) async {
    await StorageService().prefs.setString('telegram_bot_token', token);
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
      return userCredential.user;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<bool> backupToFirebase(List<model.Transaction> transactions) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      // Instead of writing to Firebase Storage, we push an encrypted payload to Firestore.
      final file = await _generateBackupFile(transactions);
      final fileContent = await file.readAsString();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'backupData': fileContent,
            'lastBackup': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      debugPrint('Firebase Backup Error: $e');
      return false;
    }
  }

  // ==================== Telegram Integration ====================

  Future<String?> fetchTelegramChatId() async {
    final token = _telegramBotToken;
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
    final token = _telegramBotToken;
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

      final url = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
      final request = http.MultipartRequest('POST', url)
        ..fields['chat_id'] = activeChatId
        ..fields['caption'] = '🔐 Your X-pense Encrypted Backup\n📅 ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}'
        ..files.add(await http.MultipartFile.fromPath('document', file.path));

      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Telegram Backup Error: $e');
      return false;
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
