// views/transaction/transaction_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import 'widgets/category_manager_sheet.dart';
import '../widgets/liquid_glass_snackbar.dart';

/// Show this as a modal bottom sheet via [showTransactionDetail].
class TransactionDetailSheet extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailSheet({Key? key, required this.transaction})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        final isDebit = transaction.isExpense;
        final vm = context.watch<TransactionViewModel>();
        final categories = vm.categories;
        String currentCategory = transaction.category;
        if (!categories.contains(currentCategory)) {
          currentCategory = vm.defaultCategory;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            32 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDebit
                          ? AppConstants.expenseRed.withAlpha(30)
                          : AppConstants.incomeGreen.withAlpha(30),
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusMedium,
                      ),
                    ),
                    child: Icon(
                      isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isDebit
                          ? AppConstants.expenseRed
                          : AppConstants.incomeGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          Formatters.date(transaction.date),
                          style: TextStyle(
                            color: AppConstants.greyText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.currency(transaction.amount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDebit
                          ? AppConstants.expenseRed
                          : AppConstants.incomeGreen,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Detail rows
              _DetailRow('Type', transaction.type),
              if (transaction.referenceNo.isNotEmpty)
                _DetailRow(
                  'Reference',
                  Formatters.reference(transaction.referenceNo),
                ),
              _DetailRow(
                'Balance after',
                Formatters.currency(transaction.balance),
              ),

              const SizedBox(height: 16),

              // Category picker
              Row(
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => showCategoryManagerSheet(context),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField2<String>(
                key: ValueKey<String>(
                  'detail-category-$currentCategory-${categories.length}',
                ),
                value: currentCategory,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  labelText: 'Type/Category',
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surface.withAlpha(AppConstants.glassFillAlpha),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha(
                        AppConstants.glassBorderAlpha,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha(
                        AppConstants.glassBorderAlpha,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(
                      color: AppConstants.primaryPurple.withAlpha(
                        AppConstants.glassFocusAlpha,
                      ),
                    ),
                  ),
                ),
                buttonStyleData: const ButtonStyleData(
                  padding: EdgeInsets.only(right: 10),
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surface.withAlpha(
                      AppConstants.glassPanelAlpha,
                    ),
                    border: Border.all(
                      color: Colors.white.withAlpha(
                        AppConstants.glassBorderAlpha,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(
                          AppConstants.glassShadowAlpha,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(
                  height: kMinInteractiveDimension,
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null && v != currentCategory) {
                    currentCategory = v;
                    setSheetState(() {});
                    context
                        .read<TransactionViewModel>()
                        .updateTransactionCategory(transaction.id, v);

                    // Show success notification
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        LiquidGlassSnackBar(
                          context: context,
                          message: 'Transaction updated',
                          type: SnackBarType.success,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppConstants.greyText)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to show the detail sheet from anywhere.
Future<void> showTransactionDetail(
  BuildContext context,
  Transaction transaction,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => TransactionDetailSheet(transaction: transaction),
  );
}
