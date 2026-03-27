import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/transaction_viewmodel.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key, this.embedInHome = false}) : super(key: key);

  final bool embedInHome;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedMonth = '';
  String _selectedYear = 'All';
  int _selectedCategoryIndex = -1;
  bool _animatePieIn = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = AppConstants.monthNames[now.month];
    _selectedYear = now.year.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animatePieIn = true);
      }
    });
  }

  List<String> _availableYears(List<Transaction> all) {
    final years = all.map((t) => t.date.year.toString()).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return ['All', ...years];
  }

  @override
  Widget build(BuildContext context) {
    final allTx = context
        .watch<TransactionViewModel>()
        .allTransactions
        .toList();
    final availableYears = _availableYears(allTx);

    final monthItems = <String>{...AppConstants.monthNames}.toList();
    final safeMonth = monthItems.contains(_selectedMonth)
        ? _selectedMonth
        : (monthItems.contains('All') ? 'All' : monthItems.first);
    final safeYear = availableYears.contains(_selectedYear)
        ? _selectedYear
        : (availableYears.contains('All') ? 'All' : availableYears.first);

    final filtered = allTx.where((t) {
      final matchMonth =
          safeMonth == 'All' ||
          AppConstants.monthNames[t.date.month] == safeMonth;
      final matchYear = safeYear == 'All' || t.date.year.toString() == safeYear;
      return matchMonth && matchYear;
    }).toList();

    if ((safeMonth != _selectedMonth || safeYear != _selectedYear) && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedMonth = safeMonth;
          _selectedYear = safeYear;
        });
      });
    }

    final Map<String, double> categoryExp = {};
    for (final t in filtered) {
      if (t.isExpense) {
        categoryExp[t.category] = (categoryExp[t.category] ?? 0) + t.debit;
      }
    }

    final sorted = categoryExp.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalExp = sorted.fold(0.0, (s, e) => s + e.value);
    final totalInc = filtered.fold(0.0, (s, t) => s + t.credit);

    final content = Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(
              AppConstants.borderRadiusMedium,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 350;
              if (compact) {
                return Column(
                  children: [
                    _buildDropdown(
                      label: 'Month',
                      value: safeMonth,
                      items: monthItems,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedMonth = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      label: 'Year',
                      value: safeYear,
                      items: availableYears,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedYear = v);
                      },
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Month',
                      value: safeMonth,
                      items: monthItems,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedMonth = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: 'Year',
                      value: safeYear,
                      items: availableYears,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedYear = v);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Expense Breakdown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sorted.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text('No expenses in selected period'),
                            ),
                          )
                        else
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.97,
                                    end: 1.0,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: const ValueKey<String>('pie-view'),
                              child: _buildPieView(sorted, totalExp),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _summaryRow(
                          'Total transactions',
                          filtered.length.toString(),
                        ),
                        _summaryRow(
                          'Total income',
                          Formatters.currency(totalInc),
                          color: AppConstants.incomeGreen,
                        ),
                        _summaryRow(
                          'Total expenses',
                          Formatters.currency(totalExp),
                          color: AppConstants.expenseRed,
                        ),
                        _summaryRow(
                          'Net',
                          Formatters.currency(totalInc - totalExp),
                          color: (totalInc - totalExp) >= 0
                              ? AppConstants.incomeGreen
                              : AppConstants.expenseRed,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_graph_outlined,
                              color: AppConstants.primaryPurple,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'AI Forecast & Analyzer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Coming soon: monthly cash-flow forecast, spending optimization suggestions, and personalized insights based on historical transactions.',
                        ),
                        SizedBox(height: 8),
                        Text('Planned modules:'),
                        SizedBox(height: 4),
                        Text('- Category overspend alerts'),
                        Text('- Month-end balance prediction'),
                        Text('- Smart savings recommendations'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedInHome) {
      return SafeArea(top: false, child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: content,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final uniqueItems = <String>{...items}.toList();
    final safeValue = uniqueItems.contains(value)
        ? value
        : (uniqueItems.contains('All') ? 'All' : uniqueItems.first);

    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final itemHeight = shortestSide < 410 ? kMinInteractiveDimension : 50.0;
    final fontSize = shortestSide < 360
        ? 11.0
        : shortestSide < 410
        ? 12.0
        : 13.0;
    final borderRadius = BorderRadius.circular(14);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final glassFill = Theme.of(
      context,
    ).colorScheme.surface.withAlpha(AppConstants.glassFillAlpha);
    final glassDropdown = Theme.of(
      context,
    ).colorScheme.surface.withAlpha(AppConstants.glassPanelAlpha);

    return DropdownButtonFormField2<String>(
      value: safeValue,
      isExpanded: true,
      style: TextStyle(fontSize: fontSize, color: onSurface),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        filled: true,
        fillColor: glassFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        labelStyle: TextStyle(
          fontSize: fontSize - 1,
          color: onSurface.withAlpha(200),
        ),
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
        maxHeight: 320,
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
      menuItemStyleData: MenuItemStyleData(height: itemHeight),
      items: uniqueItems
          .map(
            (i) => DropdownMenuItem(
              value: i,
              child: Text(
                i,
                style: TextStyle(fontSize: fontSize, color: onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppConstants.greyText)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieView(List<MapEntry<String, double>> sorted, double totalExp) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final chartSize = (constraints.maxWidth * 0.60).clamp(170.0, 240.0);

            return SizedBox(
              height: chartSize + 12,
              child: Center(
                child: SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (response == null ||
                              response.touchedSection == null) {
                            return;
                          }
                          final idx =
                              response.touchedSection!.touchedSectionIndex;
                          setState(() {
                            _selectedCategoryIndex =
                                _selectedCategoryIndex == idx ? -1 : idx;
                          });
                        },
                      ),
                      sectionsSpace: 3,
                      centerSpaceRadius: chartSize * 0.22,
                      centerSpaceColor: Theme.of(context).cardColor,
                      startDegreeOffset: -90,
                      sections: sorted.asMap().entries.map((me) {
                        final idx = me.key;
                        final entry = me.value;
                        final color = AppConstants
                            .chartColors[idx % AppConstants.chartColors.length];
                        final pct = totalExp > 0
                            ? (entry.value / totalExp) * 100
                            : 0.0;
                        final selected = idx == _selectedCategoryIndex;

                        return PieChartSectionData(
                          value: _animatePieIn ? entry.value : 0,
                          color: color,
                          radius: selected
                              ? chartSize * 0.28
                              : chartSize * 0.24,
                          title: '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%',
                          titleStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: selected ? 11 : 9,
                            shadows: [
                              Shadow(
                                color: Colors.black.withAlpha(90),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          badgeWidget: selected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(30),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    Formatters.currency(entry.value),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : null,
                          badgePositionPercentageOffset: 1.16,
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutQuart,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ...sorted.asMap().entries.map((me) {
          final idx = me.key;
          final entry = me.value;
          final pct = totalExp > 0 ? entry.value / totalExp * 100 : 0.0;
          final color =
              AppConstants.chartColors[idx % AppConstants.chartColors.length];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = _selectedCategoryIndex == idx
                    ? -1
                    : idx;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: _selectedCategoryIndex == idx
                    ? color.withAlpha(50)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${Formatters.currency(entry.value)} (${Formatters.percentage(pct)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
