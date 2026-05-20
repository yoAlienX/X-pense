import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/transaction_viewmodel.dart';
import '../../services/cloud_backup_service.dart';
import '../lock/cloud_backup_helpers.dart';
import '../../utils/constants.dart';

class CloudBackupScreen extends StatelessWidget {
  const CloudBackupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup & Restore'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            context,
            title: 'Google Drive / Firestore',
            icon: Icons.cloud_done_outlined,
            color: Colors.redAccent,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Backup to Google'),
                subtitle: const Text('Push your encrypted data to the cloud.'),
                onTap: () => handleGoogleBackup(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Restore from Google'),
                subtitle: const Text('Pull and decrypt your data from the cloud.'),
                onTap: () => handleGoogleRestore(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Telegram Bot',
            icon: Icons.telegram,
            color: Colors.blue,
            children: [
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Backup to Telegram'),
                subtitle: const Text('Send an encrypted backup file to your bot.'),
                onTap: () => showTelegramSetupDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Restore from Telegram'),
                subtitle: const Text('How to restore from your Telegram bot.'),
                onTap: () => handleTelegramRestore(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
