// views/home/widgets/balance_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/transaction.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../viewmodels/transaction_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';

class BalanceCard extends StatelessWidget {
  /// Called when the user taps the income or expense summary tile.
  final void Function(bool isIncome)? onSummaryTap;

  const BalanceCard({Key? key, this.onSummaryTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final themeVm = context.watch<ThemeViewModel>();
    final isDark = themeVm.isDarkMode;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2A2A2A), const Color(0xFF3A3A3A)]
                : [AppConstants.primaryPurple, const Color(0xFF8A5BFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Balance label + visibility toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Row(
                  children: [
                    if (vm.allTransactions.isEmpty)
                      _iconButton(
                        Icons.edit,
                        'Set Initial Balance',
                        () => _showInitialBalanceDialog(context, vm),
                      ),
                    _iconButton(
                      vm.balanceVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      vm.balanceVisible ? 'Hide Balance' : 'Show Balance',
                      () => vm.toggleBalanceVisibility(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Balance amount
            Text(
              vm.balanceVisible
                  ? Formatters.currency(vm.currentBalance)
                  : Formatters.maskedBalance(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Income / Expense tiles
            Row(
              children: [
                _SummaryTile(
                  label: 'Income',
                  amount: vm.totalIncome,
                  visible: vm.balanceVisible,
                  isIncome: true,
                  onTap: () => onSummaryTap?.call(true),
                ),
                const SizedBox(width: 16),
                _SummaryTile(
                  label: 'Expense',
                  amount: vm.totalExpense,
                  visible: vm.balanceVisible,
                  isIncome: false,
                  onTap: () => onSummaryTap?.call(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  void _showInitialBalanceDialog(
    BuildContext context,
    TransactionViewModel vm,
  ) {
    final ctrl = TextEditingController(
      text: vm.currentBalance.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Initial Balance'),
        content: TextFormField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Initial Balance (₹)',
            prefixText: '₹',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text) ?? 0.0;
              if (amount != 0.0) {
                final t = Transaction(
                  id: 'initial_balance_${DateTime.now().millisecondsSinceEpoch}',
                  date: DateTime.now(),
                  description: 'Initial Balance',
                  referenceNo: 'SYSTEM',
                  debit: amount < 0 ? amount.abs() : 0.0,
                  credit: amount > 0 ? amount : 0.0,
                  balance: amount,
                  type: amount >= 0 ? 'Credit' : 'Debit',
                  category: 'Initial Balance',
                );
                vm.addTransaction(t);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final bool visible;
  final bool isIncome;
  final VoidCallback? onTap;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.visible,
    required this.isIncome,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(22),
            borderRadius: BorderRadius.circular(
              AppConstants.borderRadiusMedium,
            ),
          ),
          child: Column(
            children: [
              Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome
                    ? AppConstants.incomeGreen
                    : AppConstants.expenseRed,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                visible
                    ? Formatters.currency(amount)
                    : Formatters.maskedBalance(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
