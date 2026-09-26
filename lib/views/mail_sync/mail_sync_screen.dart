// views/mail_sync/mail_sync_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/parsed_email_transaction.dart';
import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../viewmodels/mail_sync_viewmodel.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../widgets/liquid_glass_snackbar.dart';

/// "Sync from Email" — connect a Gmail account (via app password), fetch
/// recent bank alert mail from Canara Bank / SBI, and let the user review
/// and selectively import the parsed transactions. Nothing is written to
/// the real transaction list without an explicit confirm.
class MailSyncScreen extends StatefulWidget {
  const MailSyncScreen({Key? key}) : super(key: key);

  @override
  State<MailSyncScreen> createState() => _MailSyncScreenState();
}

class _MailSyncScreenState extends State<MailSyncScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MailSyncViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sync from Email')),
      body: vm.isConnected ? _buildConnectedView(context, vm) : _buildConnectView(context, vm),
    );
  }

  // -------------------- Connect form --------------------

  Widget _buildConnectView(BuildContext context, MailSyncViewModel vm) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Connect a Gmail account',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Only used to fetch alert emails from Canara Bank and SBI so you '
          'can review and import them as transactions. Your credential is '
          'stored on this device only, never sent anywhere but Gmail.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Gmail address'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'App password',
            helperText:
                'Generate one at myaccount.google.com/apppasswords — '
                'not your normal Gmail password. Requires 2-Step '
                'Verification to be enabled on the account.',
            helperMaxLines: 3,
          ),
        ),
        if (vm.error != null) ...[
          const SizedBox(height: 12),
          Text(vm.error!, style: const TextStyle(color: AppConstants.expenseRed)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: vm.isConnecting ? null : () => _connect(context, vm),
            child: vm.isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
          ),
        ),
      ],
    );
  }

  Future<void> _connect(BuildContext context, MailSyncViewModel vm) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Enter both an email address and an app password',
          type: SnackBarType.error,
        ),
      );
      return;
    }

    final ok = await vm.connect(email, password);
    if (ok && context.mounted) {
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Connected. Tap "Sync Now" to fetch recent bank mail.',
          type: SnackBarType.success,
        ),
      );
    }
  }

  // -------------------- Connected / review view --------------------

  Widget _buildConnectedView(BuildContext context, MailSyncViewModel vm) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Connected: ${vm.connectedEmail ?? ''}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await vm.disconnect();
                },
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: vm.isSyncing ? null : () => vm.sync(),
              icon: vm.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(vm.isSyncing ? 'Syncing…' : 'Sync Now'),
            ),
          ),
        ),
        if (vm.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(vm.error!, style: const TextStyle(color: AppConstants.expenseRed)),
          ),
        if (vm.lastUnparsedCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${vm.lastUnparsedCount} email(s) from your banks didn\'t match a '
              'known format and were skipped — check those manually.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: vm.candidates.isEmpty
              ? Center(
                  child: Text(
                    vm.isSyncing ? '' : 'No new transactions to review.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: vm.candidates.length,
                  itemBuilder: (context, index) {
                    final c = vm.candidates[index];
                    return _CandidateTile(
                      candidate: c,
                      selected: vm.isSelected(c.messageKey),
                      onToggle: () => vm.toggleSelected(c.messageKey),
                      onEdited: (updated) => vm.updateCandidate(c.messageKey, updated),
                    );
                  },
                ),
        ),
        if (vm.candidates.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: vm.selectedCount == 0 ? null : () => _importSelected(context, vm),
                  child: Text('Import ${vm.selectedCount} transaction(s)'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _importSelected(BuildContext context, MailSyncViewModel vm) async {
    final txVm = context.read<TransactionViewModel>();
    final selected = vm.selectedCandidates;
    const uuid = Uuid();

    final transactions = selected
        .map(
          (c) => Transaction(
            id: uuid.v4(),
            date: c.date,
            description: c.description,
            referenceNo: c.referenceNo,
            debit: c.debit,
            credit: c.credit,
            balance: c.balance ?? 0.0,
            type: c.type,
            category: c.category,
          ),
        )
        .toList();

    await txVm.addMultipleTransactions(transactions);
    await vm.markThisBatchReviewed();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Imported ${transactions.length} transaction(s)',
          type: SnackBarType.success,
        ),
      );
    }
  }
}

class _CandidateTile extends StatelessWidget {
  final ParsedEmailTransaction candidate;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<ParsedEmailTransaction> onEdited;

  const _CandidateTile({
    required this.candidate,
    required this.selected,
    required this.onToggle,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = candidate.type == 'debit';
    final amount = isDebit ? candidate.debit : candidate.credit;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Checkbox(value: selected, onChanged: (_) => onToggle()),
        title: Text(candidate.description),
        subtitle: Text(
          '${candidate.sourceBank} · '
          '${candidate.date.day}/${candidate.date.month}/${candidate.date.year} · '
          '${candidate.category}',
        ),
        trailing: Text(
          '${isDebit ? '-' : '+'}₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDebit ? AppConstants.expenseRed : AppConstants.incomeGreen,
          ),
        ),
        onTap: () => _showEditSheet(context),
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context) async {
    final amountController = TextEditingController(
      text: (candidate.type == 'debit' ? candidate.debit : candidate.credit).toStringAsFixed(2),
    );
    final descController = TextEditingController(text: candidate.description);
    String type = candidate.type;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit before importing',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    candidate.rawSnippet,
                    style: Theme.of(ctx).textTheme.bodySmall,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Expense'),
                          value: 'debit',
                          groupValue: type,
                          onChanged: (v) => setLocalState(() => type = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Income'),
                          value: 'credit',
                          groupValue: type,
                          onChanged: (v) => setLocalState(() => type = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                        onEdited(
                          candidate.copyWith(
                            description: descController.text.trim(),
                            type: type,
                            debit: type == 'debit' ? amount : 0.0,
                            credit: type == 'credit' ? amount : 0.0,
                          ),
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
