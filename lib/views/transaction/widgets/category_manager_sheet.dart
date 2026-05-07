import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../viewmodels/transaction_viewmodel.dart';
import '../../widgets/liquid_glass_snackbar.dart';

Future<void> showCategoryManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CategoryManagerSheet(),
  );
}

class _CategoryManagerSheet extends StatefulWidget {
  const _CategoryManagerSheet();

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory(TransactionViewModel vm) async {
    final text = _newCategoryController.text.trim();
    if (text.isEmpty) return;

    if (vm.categories.contains(text)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        LiquidGlassSnackBar(
          context: context,
          message: 'Category already exists',
          type: SnackBarType.warning,
        ),
      );
      return;
    }

    await vm.addCategory(text);
    _newCategoryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TransactionViewModel>();
    final categories = vm.categories;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Set a default category, add new ones, or remove existing categories.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'New category',
                      hintText: 'e.g. Travel',
                    ),
                    onSubmitted: (_) => _addCategory(vm),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _addCategory(vm),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isDefault = category == vm.defaultCategory;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Radio<String>(
                        value: category,
                        groupValue: vm.defaultCategory,
                        onChanged: (v) {
                          if (v != null) {
                            vm.setDefaultCategory(v);
                          }
                        },
                      ),
                      title: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: isDefault ? const Text('Default') : null,
                      trailing: IconButton(
                        onPressed: categories.length <= 1
                            ? null
                            : () async {
                                await vm.deleteCategory(category);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    LiquidGlassSnackBar(
                                      context: context,
                                      message: 'Category "$category" deleted',
                                      type: SnackBarType.success,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete category',
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
