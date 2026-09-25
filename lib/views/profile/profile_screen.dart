import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/cloud_backup_service.dart';
import '../widgets/liquid_glass_snackbar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backupService = context.watch<CloudBackupService>();
    final user = backupService.currentUser;
    final botToken = backupService.telegramBotToken;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Accounts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Google Profile Section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, size: 40, color: Colors.redAccent)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'Not signed in',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? 'Sign in to Google to sync backups.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (user != null)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await backupService.signOut();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            LiquidGlassSnackBar(
                              context: context,
                              message: 'Signed out of Google account.',
                              type: SnackBarType.info,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () async {
                        final signedInUser = await backupService.signInWithGoogle();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            LiquidGlassSnackBar(
                              context: context,
                              message: signedInUser != null ? 'Signed in successfully.' : 'Sign-in cancelled.',
                              type: signedInUser != null ? SnackBarType.success : SnackBarType.error,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In with Google'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Telegram Profile Section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    child: const Icon(Icons.telegram, size: 40, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    botToken.isNotEmpty ? 'Telegram Bot Linked' : 'No Bot Linked',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    botToken.isNotEmpty
                        ? 'Token: ...${botToken.substring(botToken.length > 5 ? botToken.length - 5 : 0)}'
                        : 'Link a bot in the backup menu.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (botToken.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await backupService.setTelegramBotToken('');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            LiquidGlassSnackBar(
                              context: context,
                              message: 'Telegram bot unlinked.',
                              type: SnackBarType.info,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.link_off, color: Colors.blue),
                      label: const Text('Disconnect Bot', style: TextStyle(color: Colors.blue)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
