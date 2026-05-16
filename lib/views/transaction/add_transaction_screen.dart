// views/transaction/add_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui' as dart_ui;

import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import 'widgets/category_manager_sheet.dart';
import '../widgets/liquid_glass_snackbar.dart';

class AddTransactionScreen extends StatefulWidget {
  /// When provided the screen acts as an edit form for this transaction.
  final Transaction? existing;

  const AddTransactionScreen({Key? key, this.existing}) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _amtCtrl;

  late String _type; // 'Debit' or 'Credit'
  late String _category;
  late String _account;
  late DateTime _date;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final vm = context.read<TransactionViewModel>();
    final t = widget.existing;
    _descCtrl = TextEditingController(text: t?.description ?? '');
    _refCtrl = TextEditingController(text: t?.referenceNo ?? '');
    _amtCtrl = TextEditingController(
      text: t != null
          ? (t.debit > 0 ? t.debit : t.credit).toStringAsFixed(2)
          : '',
    );
    _type = t != null ? (t.debit > 0 ? 'Debit' : 'Credit') : 'Debit';
    _category = t?.category ?? vm.defaultCategory;
    _account = t?.account ?? (vm.accounts.isNotEmpty ? vm.accounts.first : 'Canara Bank');
    _date = t?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _refCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amtCtrl.text.trim()) ?? 0.0;
    final vm = context.read<TransactionViewModel>();
    final validCategory = vm.categories.contains(_category)
        ? _category
        : vm.defaultCategory;
    final validAccount = vm.accounts.contains(_account) ? _account : (vm.accounts.isNotEmpty ? vm.accounts.first : 'Canara Bank');
    final now = DateTime.now();
    final effectiveDate = DateTime(
      _date.year,
      _date.month,
      _date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        date: _date,
        description: _descCtrl.text.trim(),
        referenceNo: _refCtrl.text.trim(),
        debit: _type == 'Debit' ? amount : 0.0,
        credit: _type == 'Credit' ? amount : 0.0,
        type: _type,
        category: validCategory,
        account: validAccount,
        balance: 0.0,
      );
      await vm.updateTransaction(widget.existing!.id, updated);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          LiquidGlassSnackBar(
            context: context,
            message: 'Transaction updated successfully',
            type: SnackBarType.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      final t = Transaction(
        id: const Uuid().v4(),
        date: effectiveDate,
        description: _descCtrl.text.trim(),
        referenceNo: _refCtrl.text.trim(),
        debit: _type == 'Debit' ? amount : 0.0,
        credit: _type == 'Credit' ? amount : 0.0,
        balance: 0.0,
        type: _type,
        category: validCategory,
        account: validAccount,
      );
      await vm.addTransaction(t);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          LiquidGlassSnackBar(
            context: context,
            message: 'Transaction added successfully',
            type: SnackBarType.success,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final categories = vm.categories;
    final selectedCategory = categories.contains(_category)
        ? _category
        : vm.defaultCategory;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type toggle
                _SectionLabel('Transaction Type'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TypeButton(
                      label: 'Debit',
                      icon: Icons.arrow_upward,
                      selected: _type == 'Debit',
                      color: AppConstants.expenseRed,
                      onTap: () => setState(() => _type = 'Debit'),
                    ),
                    const SizedBox(width: 12),
                    _TypeButton(
                      label: 'Credit',
                      icon: Icons.arrow_downward,
                      selected: _type == 'Credit',
                      color: AppConstants.incomeGreen,
                      onTap: () => setState(() => _type = 'Credit'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount
                _SectionLabel('Amount'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amtCtrl,
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    hintText: '0.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null)
                      return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description
                _SectionLabel('Description'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Grocery shopping',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // Reference
                _SectionLabel('Reference (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _refCtrl,
                  decoration: const InputDecoration(
                    hintText: 'UPI/bank reference',
                  ),
                ),
                const SizedBox(height: 20),

                // Category
                Row(
                  children: [
                    const _SectionLabel('Category'),
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
                    'category-$selectedCategory-${categories.length}',
                  ),
                  value: selectedCategory,
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Type/Category',
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface.withAlpha(
                      AppConstants.glassFillAlpha,
                    ),
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
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 20),

                // Date
                _SectionLabel('Date'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusSmall,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF3E3E3E)
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusSmall,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppConstants.primaryPurple,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          Formatters.date(_date),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Account
                const _SectionLabel('Account'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: vm.accounts.length,
                    itemBuilder: (context, index) {
                      final account = vm.accounts[index];
                      final isSelected = account == _account;
                      final accountBalance = vm.getAccountBalance(account);
                      return GestureDetector(
                        onTap: () => setState(() => _account = account),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppConstants.primaryPurple.withAlpha(50)
                                : Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: isSelected
                                  ? AppConstants.primaryPurple
                                  : Colors.grey.withAlpha(80),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: isSelected ? AppConstants.primaryPurple : Colors.grey,
                              ),
                              const Spacer(),
                              Text(
                                account,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vm.balanceVisible ? Formatters.currency(accountBalance) : '₹ •••••',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 80), // Extra space for FAB
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Theme(
        data: Theme.of(context).copyWith(
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 0,
            hoverElevation: 0,
            focusElevation: 0,
            highlightElevation: 0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppConstants.incomeGreen.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: AppConstants.incomeGreen.withOpacity(0.3),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: AppConstants.incomeGreen.withOpacity(0.5),
                  highlightColor: Colors.transparent,
                ),
                child: FloatingActionButton(
                  onPressed: _submit,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  hoverElevation: 0,
                  focusElevation: 0,
                  highlightElevation: 0,
                  splashColor: AppConstants.incomeGreen.withOpacity(0.5),
                  child: const Icon(Icons.check, color: Colors.white, size: 28),
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(30) : Colors.transparent,
            border: Border.all(
              color: selected ? color : Colors.grey.shade400,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(
              AppConstants.borderRadiusMedium,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
