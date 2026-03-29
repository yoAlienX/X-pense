// views/home/widgets/transaction_card.dart
import 'package:flutter/material.dart';

import '../../../models/transaction.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(String action) onAction; // 'edit' or 'delete'

  const TransactionCard({
    Key? key,
    required this.transaction,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.isExpense;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? AppConstants.primaryPurple.withAlpha(58)
        : AppConstants.primaryPurple.withAlpha(30);

    final iconBg = selected
        ? Colors.blue.shade50
        : (isDebit ? Colors.red.shade50 : Colors.green.shade50);
    final iconColor = selected
        ? Colors.blue
        : (isDebit ? AppConstants.expenseRed : AppConstants.incomeGreen);
    final iconData = isDebit ? Icons.arrow_upward : Icons.arrow_downward;
    final categoryBg = isDark
        ? const Color(0xFF273142)
        : const Color(0xFFE8EEFF);
    final categoryTextColor = isDark
        ? const Color(0xFFBFD4FF)
        : const Color(0xFF233A8B);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? selectedBg : null,
      elevation: selected ? 3 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        side: selected
            ? BorderSide(
                color: AppConstants.primaryPurple.withAlpha(175),
                width: 1.1,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              // Leading icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusMedium,
                  ),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              // Description + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          Formatters.date(transaction.date),
                          style: TextStyle(
                            color: AppConstants.greyText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: categoryBg,
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadiusSmall,
                            ),
                          ),
                          child: Text(
                            transaction.category,
                            style: TextStyle(
                              color: categoryTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Amount
              Text(
                Formatters.currency(transaction.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDebit
                      ? AppConstants.expenseRed
                      : AppConstants.incomeGreen,
                ),
              ),
              if (selectionMode) ...[
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected
                      ? AppConstants.primaryPurple
                      : AppConstants.greyText,
                ),
              ],
              if (!selectionMode) ...[
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withAlpha(
                        AppConstants.glassBorderAlpha,
                      ),
                      width: 0.7,
                    ),
                  ),
                  constraints: const BoxConstraints(minWidth: 22),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: const Text('Edit')),
                    PopupMenuItem(value: 'delete', child: const Text('Delete')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
