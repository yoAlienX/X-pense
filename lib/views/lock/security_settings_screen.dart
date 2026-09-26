import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/csv_service.dart';
import '../../services/storage_service.dart';
import '../../services/crypto_service.dart';
import '../../utils/constants.dart';
import '../../viewmodels/app_lock_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/transaction.dart';
import '../../utils/formatters.dart';
import '../../services/cloud_backup_service.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../mail_sync/mail_sync_screen.dart';
import '../widgets/liquid_glass_snackbar.dart';
import '../widgets/radial_theme_switch.dart';
import 'lock_overlay_dialog.dart';
import 'cloud_backup_helpers.dart';
import '../backup/cloud_backup_screen.dart';
import '../profile/profile_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({Key? key, this.embedInHome = false})
    : super(key: key);

  final bool embedInHome;

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Account Manager Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AccountManagerSheet extends StatefulWidget {
  const _AccountManagerSheet();

  @override
  State<_AccountManagerSheet> createState() => _AccountManagerSheetState();
}

class _AccountManagerSheetState extends State<_AccountManagerSheet> {
  final TextEditingController _newAccountController = TextEditingController();
  final TextEditingController _initialBalanceController = TextEditingController();

  @override
  void dispose() {
    _newAccountController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _addAccount(TransactionViewModel vm) async {
    final text = _newAccountController.text.trim();
    final balanceText = _initialBalanceController.text.trim();
    if (text.isEmpty) return;

    if (vm.accounts.contains(text)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Account already exists',
          type: SnackBarType.warning,
        ),
      );
      return;
    }

    await vm.addAccount(text);

    final initialBalance = double.tryParse(balanceText) ?? 0.0;
    if (initialBalance != 0.0) {
      final t = Transaction(
        id: 'initial_balance_${DateTime.now().millisecondsSinceEpoch}_$text',
        date: DateTime.now(),
        description: 'Initial Balance',
        referenceNo: 'SYSTEM',
        debit: initialBalance < 0 ? initialBalance.abs() : 0.0,
        credit: initialBalance > 0 ? initialBalance : 0.0,
        balance: initialBalance,
        type: initialBalance >= 0 ? 'Credit' : 'Debit',
        category: 'Initial Balance',
        account: text,
      );
      await vm.addTransaction(t);
    }

    _newAccountController.clear();
    _initialBalanceController.clear();
  }

  void _showEditBalanceDialog(BuildContext context, TransactionViewModel vm, String account, double currentBalance) {
    final ctrl = TextEditingController(text: currentBalance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $account Balance'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New Balance',
            hintText: '0.00',
            prefixText: '₹ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text) ?? 0.0;
              await vm.editAccountBalance(account, val);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  LiquidGlassSnackBar(
                    context: context,
                    message: 'Balance updated for $account',
                    type: SnackBarType.success,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final accounts = vm.accounts;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Manage Accounts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Add Account Form
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _newAccountController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Account Name',
                                hintText: 'e.g. Credit Card',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _initialBalanceController,
                              textInputAction: TextInputAction.done,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Initial Bal',
                                hintText: '0.00',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onSubmitted: (_) => _addAccount(vm),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _addAccount(vm),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Accounts List
                Container(
                  color: Colors.black.withOpacity(0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Existing Accounts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.35,
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          shrinkWrap: true,
                          itemCount: accounts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final account = accounts[index];
                            final balance = vm.getAccountBalance(account);
                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_outlined, color: AppConstants.primaryPurple, size: 20),
                                ),
                                title: Text(
                                  account,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  vm.balanceVisible ? Formatters.currency(balance) : '₹ •••••',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        _showEditBalanceDialog(context, vm, account, balance);
                                      },
                                      icon: const Icon(Icons.edit_outlined, color: AppConstants.primaryPurple),
                                      tooltip: 'Edit balance',
                                    ),
                                    IconButton(
                                      onPressed: accounts.length <= 1
                                          ? null
                                          : () async {
                                              await vm.deleteAccount(account);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).clearSnackBars();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  LiquidGlassSnackBar(
                                                    context: context,
                                                    message: 'Account "$account" deleted',
                                                    type: SnackBarType.success,
                                                  ),
                                                );
                                              }
                                            },
                                      icon: const Icon(Icons.delete_outline, color: AppConstants.expenseRed),
                                      tooltip: 'Delete account',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final TextEditingController _setupPassController = TextEditingController();
  final TextEditingController _setupConfirmController = TextEditingController();
  final TextEditingController _setupAnswerOneController =
      TextEditingController();
  final TextEditingController _setupAnswerTwoController =
      TextEditingController();

  final TextEditingController _resetAnswerOneController =
      TextEditingController();
  final TextEditingController _resetAnswerTwoController =
      TextEditingController();
  final TextEditingController _resetPassController = TextEditingController();
  final TextEditingController _resetConfirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppLockViewModel>().refreshBiometricAvailability();
    });
  }

  @override
  void dispose() {
    _setupPassController.dispose();
    _setupConfirmController.dispose();
    _setupAnswerOneController.dispose();
    _setupAnswerTwoController.dispose();
    _resetAnswerOneController.dispose();
    _resetAnswerTwoController.dispose();
    _resetPassController.dispose();
    _resetConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppLockViewModel>();
    final cloudBackupService = context.watch<CloudBackupService>();
    final user = cloudBackupService.currentUser;
    final botToken = cloudBackupService.telegramBotToken;

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Header
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 90,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                              child: user == null
                                  ? Icon(Icons.person, size: 45, color: Theme.of(context).colorScheme.primary)
                                  : null,
                            ),
                          ),
                          if (botToken.isNotEmpty)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                                ),
                                child: const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.blue,
                                  child: Icon(Icons.telegram, size: 24, color: Colors.white),
                                ),
                              ),
                            ),
                          if (user != null && botToken.isEmpty)
                            Positioned(
                              right: 10,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cloud_done, size: 16, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? (botToken.isNotEmpty ? 'Telegram Connected' : 'Not Signed In'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.email!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── Theme Section ─────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Passcode Lock',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vm.passcodeEnabled
                      ? 'Your app is protected with passcode lock.'
                      : 'Set a passcode to protect your app data.',
                ),
                const SizedBox(height: 20),
                if (!vm.passcodeEnabled)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _showSetupPasscodeDialog(context, vm),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Set Passcode'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showResetPasscodeDialog(context, vm),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset Passcode'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await vm.disablePasscode();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              LiquidGlassSnackBar(
                                context: context,
                                message: 'Passcode lock disabled',
                                type: SnackBarType.success,
                              ),
                            );
                          },
                          icon: const Icon(Icons.lock_open_outlined),
                          label: const Text('Disable'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Use Biometrics'),
                  subtitle: Text(
                    vm.biometricAvailable
                        ? 'Unlock with biometrics where supported.'
                        : 'Biometric authentication is not available on this device.',
                  ),
                  value: vm.biometricEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (!vm.passcodeEnabled)
                      ? null
                      : (enabled) async {
                          final ok = await vm.setBiometricEnabled(enabled);
                          if (!ok && context.mounted) {
                            final errorMessage = vm.lastBiometricError.isEmpty
                                ? 'Could not enable biometric unlock'
                                : vm.lastBiometricError;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              LiquidGlassSnackBar(
                                context: context,
                                message: errorMessage,
                                type: SnackBarType.error,
                              ),
                            );
                          }
                        },
                ),
                if (vm.passcodeEnabled) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        context.read<TransactionViewModel>().forceMaskBalance();
                        vm.lockApp();
                      });
                    },
                    icon: const Icon(Icons.lock),
                    label: const Text('Lock App Now'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Accounts & Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _showAccountManager(context),
                      tooltip: 'Add Account',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage accounts and customize balance visibility.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text('Show Total Balance'),
                  subtitle: const Text('Combine balances across all accounts'),
                  value: context.watch<TransactionViewModel>().showTotalBalance,
                  onChanged: (val) {
                    context.read<TransactionViewModel>().setShowTotalBalance(val);
                  },
                  activeColor: AppConstants.primaryPurple,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                Consumer<TransactionViewModel>(
                  builder: (context, txVm, _) {
                    final accounts = txVm.accounts;
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final balance = txVm.getAccountBalance(account);
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withAlpha(
                              AppConstants.glassFillAlpha,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, color: AppConstants.primaryPurple),
                                  const SizedBox(width: 12),
                                  Text(
                                    account,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    txVm.balanceVisible ? Formatters.currency(balance) : '₹ •••••',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      txVm.balanceVisible ? Icons.visibility : Icons.visibility_off,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      if (txVm.balanceVisible) {
                                        await txVm.toggleBalanceVisibility();
                                      } else {
                                        final lockVm = context.read<AppLockViewModel>();
                                        if (lockVm.passcodeEnabled) {
                                          final authSuccess = await lockVm.authenticate(() => showLockOverlayDialog(context));
                                          if (authSuccess) {
                                            await txVm.toggleBalanceVisibility();
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).clearSnackBars();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                LiquidGlassSnackBar(
                                                  context: context,
                                                  message: 'Authentication required to reveal balances',
                                                  type: SnackBarType.error,
                                                ),
                                              );
                                            }
                                          }
                                        } else {
                                          await txVm.toggleBalanceVisibility();
                                        }
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ── CSV Section ───────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Import or export your transactions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final txVm = context.read<TransactionViewModel>();
                          try {
                            final csvService = CsvService();
                            final parsed = await csvService.importFromFile();
                            if (parsed == null) return;
                            await txVm.addMultipleTransactions(parsed);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                LiquidGlassSnackBar(
                                  context: context,
                                  message:
                                      'Imported ${parsed.length} transactions',
                                  type: SnackBarType.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                LiquidGlassSnackBar(
                                  context: context,
                                  message: 'Import failed: $e',
                                  type: SnackBarType.error,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Import CSV'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final txVm = context.read<TransactionViewModel>();
                          final crypto = CryptoService();

                          if (!crypto.hasSecretKey) {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Unencrypted Backup'),
                                content: const Text(
                                  'You have not set up a Secret Encryption Key. '
                                  'Your export will be saved in PLAIN TEXT as a standard .csv file.\n\n'
                                  'Do you want to proceed without encryption?'
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    child: const Text('Proceed Anyway'),
                                  ),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                          }

                          try {
                            final csvService = CsvService();
                            await csvService.exportAndShare(
                              txVm.allTransactions.toList(),
                              isBackup: true, // Will automatically use .enc if crypto is set
                              subject: 'Expense Tracker Full Backup',
                              text:
                                  'Complete backup of ${txVm.allTransactions.length} transactions.',
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                LiquidGlassSnackBar(
                                  context: context,
                                  message: 'Export failed: $e',
                                  type: SnackBarType.error,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Export Backup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ── Cloud Backups Section ────────────────────────────────────────
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_sync_outlined, color: Colors.blue),
            ),
            title: Text(
              'Cloud Backup & Restore',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Sync or restore encrypted backups to Google Drive or Telegram.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CloudBackupScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // ── Mail Sync Section ────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync from Email',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect Gmail to pull in Canara Bank / SBI transaction '
                  'alerts for review before they\'re added.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MailSyncScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('Open Mail Sync'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ── Clear All Data Section ────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data & Storage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Clear cache or permanently delete all transactions and data',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // Archive Old Data
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                    onPressed: () => _showArchiveDialog(context),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive Old Transactions'),
                  ),
                ),
                const SizedBox(height: 10),

                // Clear All Data
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.expenseRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final shouldClear = await showDialog<bool>(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            title: const Text('Clear All Data?'),
                            content: const Text(
                              'This will permanently delete all your transactions and data. This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.expenseRed,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete All'),
                              ),
                            ],
                          );
                        },
                      );

                      if (shouldClear == true && mounted) {
                        try {
                          final txVm = context.read<TransactionViewModel>();
                          await txVm.clearAllTransactions();

                          if (mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              LiquidGlassSnackBar(
                                context: context,
                                message:
                                    'All data has been cleared successfully',
                                type: SnackBarType.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              LiquidGlassSnackBar(
                                context: context,
                                message: 'Failed to clear data: $e',
                                type: SnackBarType.error,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Clear All Data'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<ThemeViewModel>(
                  builder: (context, themeVm, _) {
                    return RadialThemeSwitch(themeViewModel: themeVm);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encryption & Privacy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Update your local encryption key for maximum privacy.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                    onPressed: () {
                      _showUpdateCryptoKeyDialog(context);
                    },
                    icon: const Icon(Icons.key),
                    label: const Text('Update Secret Key'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );

    if (widget.embedInHome) {
      return SafeArea(top: false, child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: content,
    );
  }

  void _showUpdateCryptoKeyDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Encryption Key'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Secret Key',
            hintText: 'Leave empty to disable encryption',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = ctrl.text.trim();
              try {
                // To apply the new key to existing data:
                // 1. Fetch current transaction payload.
                final txVm = context.read<TransactionViewModel>();
                final txs = txVm.allTransactions.toList();

                // 2. Set the new key.
                final cryptoService = CryptoService();
                await cryptoService.setSecretKey(newKey);

                // 3. Resave transactions using the new key.
                await txVm.addMultipleTransactions([]); // trigger a re-save natively via ViewModel or call save manually
                final storageService = StorageService();
                await storageService.saveTransactions(txs);
                // 4. Save Hash locally so we know if there is an active key on boot.
                if (newKey.isNotEmpty) {
                  await storageService.prefs.setString('encryption_hash', cryptoService.generateKeyHash());
                } else {
                  await storageService.prefs.remove('encryption_hash');
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    LiquidGlassSnackBar(
                      context: context,
                      message: 'Encryption key updated successfully',
                      type: SnackBarType.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    LiquidGlassSnackBar(
                      context: context,
                      message: 'Failed to update key',
                      type: SnackBarType.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAccountManager(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AccountManagerSheet(),
    );
  }

  void _showArchiveDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (ctx, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
                    width: 0.8,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.archive_outlined, size: 24, color: AppConstants.primaryPurple),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Archive Old Transactions',
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This will export transactions older than the selected period and replace them with a single Carry-Forward balance transaction.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    _ArchiveOptionTile(title: 'Older than 3 months', onTap: () { Navigator.pop(ctx); _performArchive(context, 3); }),
                    _ArchiveOptionTile(title: 'Older than 6 months', onTap: () { Navigator.pop(ctx); _performArchive(context, 6); }),
                    _ArchiveOptionTile(title: 'Older than 1 year', onTap: () { Navigator.pop(ctx); _performArchive(context, 12); }),
                    _ArchiveOptionTile(title: 'Older than 2 years', onTap: () { Navigator.pop(ctx); _performArchive(context, 24); }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _performArchive(BuildContext context, int months) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: 30 * months));
    final txVm = context.read<TransactionViewModel>();
    await txVm.archiveOldTransactions(cutoffDate);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Old transactions archived successfully',
          type: SnackBarType.success,
        ),
      );
    }
  }

  Future<void> _showSetupPasscodeDialog(
    BuildContext context,
    AppLockViewModel vm,
  ) async {
    _setupPassController.clear();
    _setupConfirmController.clear();
    _setupAnswerOneController.clear();
    _setupAnswerTwoController.clear();

    String questionOne = AppLockViewModel.securityQuestionOptions.first;
    String questionTwo = AppLockViewModel.securityQuestionOptions[1];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String? error;
        final onSurface = Theme.of(ctx).colorScheme.onSurface;

        InputDecoration glassInputDecoration({
          required String label,
          String? hint,
        }) {
          return InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: Theme.of(
              ctx,
            ).colorScheme.surface.withAlpha(AppConstants.glassFillAlpha),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppConstants.primaryPurple.withAlpha(
                  AppConstants.glassFocusAlpha,
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface.withAlpha(
                        AppConstants.glassPanelAlpha,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha(
                          AppConstants.glassBorderAlpha,
                        ),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.72,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryPurple.withAlpha(
                                      30,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Create Passcode Lock',
                                  style: Theme.of(ctx).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _setupPassController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 12,
                              textInputAction: TextInputAction.next,
                              decoration: glassInputDecoration(
                                label: 'Passcode',
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _setupConfirmController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 12,
                              textInputAction: TextInputAction.next,
                              decoration: glassInputDecoration(
                                label: 'Confirm passcode',
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: questionOne,
                              style: TextStyle(color: onSurface),
                              dropdownColor: Theme.of(ctx).colorScheme.surface
                                  .withAlpha(AppConstants.glassPanelAlpha),
                              decoration: glassInputDecoration(
                                label: 'Security question 1',
                              ),
                              items: AppLockViewModel.securityQuestionOptions
                                  .map(
                                    (q) => DropdownMenuItem(
                                      value: q,
                                      child: Text(q),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setLocalState(() => questionOne = v);
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _setupAnswerOneController,
                              textInputAction: TextInputAction.next,
                              decoration: glassInputDecoration(
                                label: 'Answer 1',
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: questionTwo,
                              style: TextStyle(color: onSurface),
                              dropdownColor: Theme.of(ctx).colorScheme.surface
                                  .withAlpha(AppConstants.glassPanelAlpha),
                              decoration: glassInputDecoration(
                                label: 'Security question 2',
                              ),
                              items: AppLockViewModel.securityQuestionOptions
                                  .map(
                                    (q) => DropdownMenuItem(
                                      value: q,
                                      child: Text(q),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setLocalState(() => questionTwo = v);
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _setupAnswerTwoController,
                              textInputAction: TextInputAction.done,
                              decoration: glassInputDecoration(
                                label: 'Answer 2',
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                error!,
                                style: const TextStyle(
                                  color: AppConstants.expenseRed,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      FocusScope.of(ctx).unfocus();
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final pass = _setupPassController.text
                                          .trim();
                                      final confirm = _setupConfirmController
                                          .text
                                          .trim();
                                      final answerOne =
                                          _setupAnswerOneController.text.trim();
                                      final answerTwo =
                                          _setupAnswerTwoController.text.trim();

                                      if (pass.length < 4) {
                                        setLocalState(
                                          () => error =
                                              'Passcode must be at least 4 digits',
                                        );
                                        return;
                                      }
                                      if (pass != confirm) {
                                        setLocalState(
                                          () => error =
                                              'Passcode confirmation does not match',
                                        );
                                        return;
                                      }
                                      if (questionOne == questionTwo) {
                                        setLocalState(
                                          () => error =
                                              'Please choose two different questions',
                                        );
                                        return;
                                      }
                                      if (answerOne.isEmpty ||
                                          answerTwo.isEmpty) {
                                        setLocalState(
                                          () => error =
                                              'Please provide both security answers',
                                        );
                                        return;
                                      }

                                      await vm.configurePasscode(
                                        passcode: pass,
                                        questionOne: questionOne,
                                        answerOne: answerOne,
                                        questionTwo: questionTwo,
                                        answerTwo: answerTwo,
                                      );

                                      if (ctx.mounted) {
                                        FocusScope.of(ctx).unfocus();
                                        Navigator.pop(ctx);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          LiquidGlassSnackBar(
                                            context: context,
                                            message:
                                                'Passcode lock enabled successfully',
                                            type: SnackBarType.success,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showResetPasscodeDialog(
    BuildContext context,
    AppLockViewModel vm,
  ) async {
    _resetAnswerOneController.clear();
    _resetAnswerTwoController.clear();
    _resetPassController.clear();
    _resetConfirmController.clear();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String? error;
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        InputDecoration glassInputDecoration({
          required String label,
          String? hint,
        }) {
          return InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: Theme.of(
              ctx,
            ).colorScheme.surface.withAlpha(AppConstants.glassFillAlpha),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppConstants.primaryPurple.withAlpha(
                  AppConstants.glassFocusAlpha,
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface.withAlpha(
                        AppConstants.glassPanelAlpha,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha(
                          AppConstants.glassBorderAlpha,
                        ),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.72,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryPurple.withAlpha(
                                      30,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.lock_reset, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Reset Passcode',
                                  style: Theme.of(ctx).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              vm.questionOne,
                              style: TextStyle(color: onSurface),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _resetAnswerOneController,
                              textInputAction: TextInputAction.next,
                              decoration: glassInputDecoration(
                                label: 'Answer 1',
                                hint: 'Enter answer',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              vm.questionTwo,
                              style: TextStyle(color: onSurface),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _resetAnswerTwoController,
                              textInputAction: TextInputAction.next,
                              decoration: glassInputDecoration(
                                label: 'Answer 2',
                                hint: 'Enter answer',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _resetPassController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              decoration: glassInputDecoration(
                                label: 'New passcode',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _resetConfirmController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              decoration: glassInputDecoration(
                                label: 'Confirm passcode',
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                error!,
                                style: const TextStyle(
                                  color: AppConstants.expenseRed,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      FocusScope.of(ctx).unfocus();
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final newPass = _resetPassController.text
                                          .trim();
                                      final confirm = _resetConfirmController
                                          .text
                                          .trim();

                                      if (newPass.length < 4) {
                                        setLocalState(
                                          () => error =
                                              'Passcode must be at least 4 digits',
                                        );
                                        return;
                                      }
                                      if (newPass != confirm) {
                                        setLocalState(
                                          () => error =
                                              'Passcode confirmation does not match',
                                        );
                                        return;
                                      }

                                      final ok = await vm
                                          .resetPasscodeWithSecurityAnswers(
                                            answerOne:
                                                _resetAnswerOneController.text,
                                            answerTwo:
                                                _resetAnswerTwoController.text,
                                            newPasscode: newPass,
                                          );

                                      if (!ok) {
                                        setLocalState(
                                          () => error =
                                              'Security answers are incorrect',
                                        );
                                        return;
                                      }

                                      if (ctx.mounted) {
                                        FocusScope.of(ctx).unfocus();
                                        Navigator.pop(ctx);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          LiquidGlassSnackBar(
                                            context: context,
                                            message:
                                                'Passcode reset successful',
                                            type: SnackBarType.success,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Reset'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ArchiveOptionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ArchiveOptionTile({Key? key, required this.title, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
