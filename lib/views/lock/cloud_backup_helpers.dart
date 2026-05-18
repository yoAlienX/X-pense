import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/cloud_backup_service.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../widgets/liquid_glass_snackbar.dart';

Future<void> showTelegramSetupDialog(BuildContext context) async {
  final txVm = context.read<TransactionViewModel>();
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      bool isVerifying = false;
      String tokenInput = '';
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Telegram Bot Backup'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '1. Create a bot using @BotFather on Telegram.\n'
                    '2. Paste the Bot Token below.\n'
                    '3. Open your bot on Telegram and send a "hello" message to it.\n'
                    '4. Tap "Verify & Backup".',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (val) => tokenInput = val,
                    decoration: const InputDecoration(
                      labelText: 'Bot Token',
                      hintText: '1234567890:ABCdefGhI...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final Uri url = Uri.parse('https://t.me/BotFather');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open @BotFather'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  if (tokenInput.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      LiquidGlassSnackBar(
                        context: context,
                        message: 'Please enter a Bot Token',
                        type: SnackBarType.warning,
                      ),
                    );
                    return;
                  }

                  setState(() => isVerifying = true);
                  final backupService = CloudBackupService();
                  await backupService.setTelegramBotToken(tokenInput.trim());

                  final chatId = await backupService.fetchTelegramChatId();

                  if (chatId != null && chatId.isNotEmpty) {
                    final success = await backupService.backupToTelegram(txVm.allTransactions);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        LiquidGlassSnackBar(
                          context: context,
                          message: success ? 'Backup sent to Telegram!' : 'Failed to send backup.',
                          type: success ? SnackBarType.success : SnackBarType.error,
                        ),
                      );
                    }
                  } else {
                    setState(() => isVerifying = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        LiquidGlassSnackBar(
                          context: context,
                          message: 'Could not detect chat. Did you send a message?',
                          type: SnackBarType.warning,
                        ),
                      );
                    }
                  }
                },
                child: isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify & Backup'),
              ),
            ],
          );
        }
      );
    },
  );
}

Future<void> handleGoogleBackup(BuildContext context) async {
  final txVm = context.read<TransactionViewModel>();
  final backupService = CloudBackupService();

  // Show progress dialog instead of generic snackbars
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Connecting to Google..."),
          ],
        ),
      );
    },
  );

  final user = await backupService.signInWithGoogle();

  if (user == null) {
    if (context.mounted) {
      Navigator.of(context).pop(); // Close dialog
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Google Sign-In failed or cancelled.',
          type: SnackBarType.error,
        ),
      );
    }
    return;
  }

  if (context.mounted) {
    Navigator.of(context).pop(); // Close connecting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Uploading to Firestore..."),
            ],
          ),
        );
      },
    );
  }

  final success = await backupService.backupToFirebase(txVm.allTransactions);

  if (context.mounted) {
    Navigator.of(context).pop(); // Close uploading dialog
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      LiquidGlassSnackBar(
        context: context,
        message: success ? 'Successfully backed up to Firestore!' : 'Failed to upload backup.',
        type: success ? SnackBarType.success : SnackBarType.error,
      ),
    );
  }
}
