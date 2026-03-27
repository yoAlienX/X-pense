import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import '../../../utils/constants.dart';
import '../../../viewmodels/transaction_viewmodel.dart';
import '../../transaction/widgets/category_manager_sheet.dart';

class FilterBar extends StatefulWidget {
  const FilterBar({super.key, this.overlay = false});

  final bool overlay;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  String _selectedFilter = 'All';
  String _selectedMonth = 'All';
  String _selectedYear = 'All';

  void _applyToViewModel(TransactionViewModel vm) {
    if (_selectedFilter == 'Debit') {
      vm.setTypeFilter('Expense');
      vm.setCategoryFilter('All');
    } else if (_selectedFilter == 'Credit') {
      vm.setTypeFilter('Income');
      vm.setCategoryFilter('All');
    } else if (_selectedFilter == 'All') {
      vm.setTypeFilter('All');
      vm.setCategoryFilter('All');
    } else {
      vm.setTypeFilter('All');
      vm.setCategoryFilter(_selectedFilter);
    }

    vm.setMonthFilter(_selectedMonth);
    vm.setYearFilter(_selectedYear);
  }

  void _clearFilters(TransactionViewModel vm) {
    setState(() {
      _selectedFilter = 'All';
      _selectedMonth = 'All';
      _selectedYear = 'All';
    });

    vm.setTypeFilter('All');
    vm.setCategoryFilter('All');
    vm.setMonthFilter('All');
    vm.setYearFilter('All');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<TransactionViewModel>();
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final compactFieldHeight = shortestSide < 380 ? 48.0 : 50.0;
    final filterState = context
        .select<TransactionViewModel, FilterStateSnapshot>(
          (v) => FilterStateSnapshot(
            years: v.getAvailableYears(),
            categories: v.categories,
          ),
        );

    final filterOptions = ['All', 'Debit', 'Credit', ...filterState.categories];

    if (!filterOptions.contains(_selectedFilter)) {
      _selectedFilter = 'All';
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyToViewModel(vm),
      );
    }
    if (!filterState.years.contains(_selectedYear)) {
      _selectedYear = 'All';
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyToViewModel(vm),
      );
    }

    final baseFill = Theme.of(
      context,
    ).colorScheme.surface.withAlpha(AppConstants.glassContainerAlpha);

    return Container(
      margin: EdgeInsets.fromLTRB(16, widget.overlay ? 0 : 10, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseFill,
              borderRadius: BorderRadius.circular(
                AppConstants.borderRadiusMedium,
              ),
              border: Border.all(
                color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(AppConstants.glassShadowAlpha),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 430;

                    if (compact) {
                      return Column(
                        children: [
                          SizedBox(
                            height: compactFieldHeight,
                            child: _buildDropdown(
                              label: 'Type/Category',
                              initialValue: _selectedFilter,
                              items: filterOptions,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedFilter = v);
                                  _applyToViewModel(vm);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: compactFieldHeight,
                                  child: _buildDropdown(
                                    label: 'Month',
                                    initialValue: _selectedMonth,
                                    items: AppConstants.monthNames,
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedMonth = v);
                                        _applyToViewModel(vm);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: compactFieldHeight,
                                  child: _buildDropdown(
                                    label: 'Year',
                                    initialValue: _selectedYear,
                                    items: filterState.years,
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedYear = v);
                                        _applyToViewModel(vm);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: compactFieldHeight,
                            child: _buildDropdown(
                              label: 'Type/Category',
                              initialValue: _selectedFilter,
                              items: filterOptions,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedFilter = v);
                                  _applyToViewModel(vm);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: compactFieldHeight,
                            child: _buildDropdown(
                              label: 'Month',
                              initialValue: _selectedMonth,
                              items: AppConstants.monthNames,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedMonth = v);
                                  _applyToViewModel(vm);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: compactFieldHeight,
                            child: _buildDropdown(
                              label: 'Year',
                              initialValue: _selectedYear,
                              items: filterState.years,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedYear = v);
                                  _applyToViewModel(vm);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => showCategoryManagerSheet(context),
                      icon: const Icon(Icons.category_outlined, size: 17),
                      label: const Text('Categories'),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () => _clearFilters(vm),
                      icon: const Icon(Icons.clear_all, size: 17),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String initialValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final fontSize = shortestSide < 380 ? 12.0 : 13.0;
    final borderRadius = BorderRadius.circular(14);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final glassFill = Theme.of(
      context,
    ).colorScheme.surface.withAlpha(AppConstants.glassFillAlpha);
    final glassDropdown = Theme.of(
      context,
    ).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha);

    return DropdownButtonFormField2<String>(
      key: ValueKey('$label-$initialValue-${items.length}'),
      value: initialValue,
      isExpanded: true,
      style: TextStyle(fontSize: fontSize, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: glassFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        labelStyle: TextStyle(fontSize: fontSize - 1, color: textColor),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
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
          borderRadius: borderRadius,
          color: glassDropdown,
          border: Border.all(
            color: Colors.white.withAlpha(AppConstants.glassBorderAlpha),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(AppConstants.glassShadowAlpha),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
      ),
      menuItemStyleData: const MenuItemStyleData(
        height: kMinInteractiveDimension,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class FilterStateSnapshot {
  final List<String> years;
  final List<String> categories;

  FilterStateSnapshot({required this.years, required this.categories});
}
