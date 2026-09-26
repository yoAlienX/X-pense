import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/cloud_backup_service.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../widgets/liquid_glass_snackbar.dart';
import '../../services/crypto_service.dart';
import '../../services/csv_service.dart';

Future<void> showTelegramSetupDialog(BuildContext context) async {
  final txVm = context.read<TransactionViewModel>();
  final backupService = CloudBackupService();
  if (txVm.allTransactions.isNotEmpty) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text(
            'You currently have transactions in the app. Restoring will add the backup transactions on top of your existing ones.\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
    if (proceed != true) return;
  }
  final existingToken = backupService.telegramBotToken;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      bool isVerifying = false;
      String tokenInput = existingToken; // pre-fill if it exists

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Telegram Bot Backup'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existingToken.isNotEmpty) ...[
                    const Text('✓ A bot is already linked to your account. You can re-verify or change the token below.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                  ],
                  const Text(
                    '1. Create a bot using @BotFather on Telegram.\n'
                    '2. Paste the Bot Token below.\n'
                    '3. Open your bot on Telegram and send a "hello" message to it.\n'
                    '4. Tap "Verify".',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    initialValue: tokenInput,
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
                  await backupService.setTelegramBotToken(tokenInput.trim());

                  final chatId = await backupService.fetchTelegramChatId();

                  if (chatId != null && chatId.isNotEmpty) {
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        LiquidGlassSnackBar(
                          context: context,
                          message: 'Telegram Bot verified successfully!',
                          type: SnackBarType.success,
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
                    : const Text('Verify'),
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
  if (txVm.allTransactions.isNotEmpty) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text(
            'You currently have transactions in the app. Restoring will add the backup transactions on top of your existing ones.\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
    if (proceed != true) return;
  }
  final crypto = CryptoService();

  // Security Warning if not encrypted
  if (!crypto.hasSecretKey) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Unencrypted Backup Warning'),
          content: const Text(
            'You have not set up a Secret Encryption Key in the Security Settings. '
            'Proceeding will upload your transactions in PLAIN TEXT to the cloud.\n\n'
            'Do you want to proceed without encryption?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Proceed Anyway'),
            ),
          ],
        );
      },
    );

    if (proceed != true) return;
  }

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

Future<void> handleTelegramRestore(BuildContext context) async {
  final txVm = context.read<TransactionViewModel>();
  final backupService = CloudBackupService();
  if (txVm.allTransactions.isNotEmpty) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text(
            'You currently have transactions in the app. Restoring will add the backup transactions on top of your existing ones.\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
    if (proceed != true) return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Downloading from Telegram..."),
          ],
        ),
      );
    },
  );

  try {
    final data = await backupService.restoreFromTelegram();
    if (data == null) throw Exception('No data returned.');

    if (context.mounted) {
      Navigator.of(context).pop(); // Close downloading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            content: Row(
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Decrypting & Restoring..."),
              ],
            ),
          );
        },
      );
    }

    final csvService = CsvService();
    final parsed = await csvService.importFromData(data);

    if (context.mounted) {
      Navigator.of(context).pop(); // Close restoring dialog
      if (parsed != null && parsed.isNotEmpty) {
        await txVm.addMultipleTransactions(parsed, isRestore: true);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored ${parsed.length} transactions!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                await txVm.revertRestore();
              },
            ),
          ),
        );
      } else {
        throw Exception('Backup file was empty or corrupted.');
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // Ensure dialog is closed
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Restore failed: ${e.toString().replaceAll('Exception:', '').trim()}',
          type: SnackBarType.error,
        ),
      );
    }
  }
}

Future<void> handleGoogleRestore(BuildContext context) async {
  final txVm = context.read<TransactionViewModel>();
  final backupService = CloudBackupService();
  if (txVm.allTransactions.isNotEmpty) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text(
            'You currently have transactions in the app. Restoring will add the backup transactions on top of your existing ones.\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
    if (proceed != true) return;
  }

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
      Navigator.of(context).pop();
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
    Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Downloading from Firestore..."),
            ],
          ),
        );
      },
    );
  }

  try {
    final data = await backupService.restoreFromFirebase();
    if (data == null) throw Exception('No data returned.');

    if (context.mounted) {
      Navigator.of(context).pop(); // Close downloading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            content: Row(
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Decrypting & Restoring..."),
              ],
            ),
          );
        },
      );
    }

    final csvService = CsvService();
    final parsed = await csvService.importFromData(data);

    if (context.mounted) {
      Navigator.of(context).pop(); // Close restoring dialog
      if (parsed != null && parsed.isNotEmpty) {
        await txVm.addMultipleTransactions(parsed, isRestore: true);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored ${parsed.length} transactions!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                await txVm.revertRestore();
              },
            ),
          ),
        );
      } else {
        throw Exception('Backup file was empty or corrupted.');
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // Ensure dialog is closed
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Restore failed: ${e.toString().replaceAll('Exception:', '').trim()}',
          type: SnackBarType.error,
        ),
      );
    }
  }
}

Future<void> handleTelegramBackup(BuildContext context) async {
  final txVm = context.read<TransactionViewModel>();
  final backupService = CloudBackupService();
  final crypto = CryptoService();

  if (backupService.telegramBotToken.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      LiquidGlassSnackBar(
        context: context,
        message: 'Please link a Telegram bot first.',
        type: SnackBarType.warning,
      ),
    );
    return;
  }

  // Security Warning if not encrypted
  if (!crypto.hasSecretKey) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Unencrypted Backup Warning'),
          content: const Text(
            'You have not set up a Secret Encryption Key in the Security Settings. '
            'Proceeding will upload your transactions in PLAIN TEXT to Telegram.\n\n'
            'Do you want to proceed without encryption?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Proceed Anyway'),
            ),
          ],
        );
      },
    );

    if (proceed != true) return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Uploading to Telegram..."),
          ],
        ),
      );
    },
  );

  final success = await backupService.backupToTelegram(txVm.allTransactions);

  if (context.mounted) {
    Navigator.of(context).pop(); // Close dialog
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      LiquidGlassSnackBar(
        context: context,
        message: success ? 'Successfully backed up to Telegram!' : 'Failed to upload backup.',
        type: success ? SnackBarType.success : SnackBarType.error,
      ),
    );
  }
}
