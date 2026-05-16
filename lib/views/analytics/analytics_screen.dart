import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import 'widgets/animated_pie_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/animated_line_chart.dart';
import 'widgets/zero_expense_chart.dart';

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
  bool _showLineChart = false;
  String _lineChartRange = 'Weekly';
  final Set<String> _hiddenCategories = <String>{};
  final ScrollController _legendScrollController = ScrollController();

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

  @override
  void dispose() {
    _legendScrollController.dispose();
    super.dispose();
  }

  List<String> _availableYears(List<Transaction> all) {
    final years = all.map((t) => t.date.year.toString()).toSet();
    years.add(DateTime.now().year.toString());

    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
    return ['All', ...sortedYears];
  }

  @override
  Widget build(BuildContext context) {
    final allTx = context
        .watch<TransactionViewModel>()
        .allTransactions
        .toList();
    final availableYears = _availableYears(allTx);

    final monthItems = <String>{...AppConstants.monthNames}.toList();
    final defaultMonth = AppConstants.monthNames[DateTime.now().month];
    final defaultYear = DateTime.now().year.toString();

    final safeMonth = monthItems.contains(_selectedMonth)
        ? _selectedMonth
        : (monthItems.contains(defaultMonth) ? defaultMonth : monthItems.first);
    final safeYear = availableYears.contains(_selectedYear)
        ? _selectedYear
        : (availableYears.contains(defaultYear)
              ? defaultYear
              : availableYears.first);

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

    if (_selectedCategoryIndex >= sorted.length) {
      _selectedCategoryIndex = -1;
    }

    final totalExp = sorted.fold(0.0, (s, e) => s + e.value);
    final totalInc = filtered.fold(0.0, (s, t) => s + t.credit);

    final content = Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          child: Row(
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
              const SizedBox(width: 10),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Expense Breakdown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(_showLineChart ? Icons.pie_chart : Icons.show_chart),
                              onPressed: () {
                                setState(() {
                                  _showLineChart = !_showLineChart;
                                });
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sorted.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: ZeroExpenseChart()),
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
                              key: ValueKey<String>(_showLineChart ? 'line-view' : 'pie-view'),
                              child: _showLineChart ? _buildLineView(filtered) : _buildPieView(sorted, totalExp),
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
    final visibleTotal = sorted
        .where((entry) => !_hiddenCategories.contains(entry.key))
        .fold<double>(0.0, (sum, entry) => sum + entry.value);

    final legendRows = sorted.asMap().entries.map((me) {
      final idx = me.key;
      final entry = me.value;
      final visible = !_hiddenCategories.contains(entry.key);
      final pct = visibleTotal > 0 ? entry.value / visibleTotal * 100 : 0.0;
      final color =
          AppConstants.chartColors[idx % AppConstants.chartColors.length];

      return GestureDetector(
        onTap: () {
          setState(() {
            if (visible) {
              _hiddenCategories.add(entry.key);
            } else {
              _hiddenCategories.remove(entry.key);
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: _selectedCategoryIndex == idx ? color.withAlpha(50) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: visible ? Colors.transparent : AppConstants.greyText,
              width: visible ? 0 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visible ? color : Colors.transparent,
                  border: visible ? null : Border.all(color: color, width: 2),
                ),
                child: visible
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: visible ? null : AppConstants.greyText,
                  ),
                ),
              ),
              Text(
                '${Formatters.currency(entry.value)} (${Formatters.percentage(pct)})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: visible ? null : AppConstants.greyText,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

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
                  child: AnimatedPieChart(
                    size: chartSize,
                    strokeWidth: chartSize * 0.22,
                    backgroundColor: Colors.transparent,
                    onSegmentTapped: (idx) {
                      setState(() {
                        if (_selectedCategoryIndex == idx) {
                           _selectedCategoryIndex = -1;
                        } else {
                           _selectedCategoryIndex = idx;
                        }
                      });
                    },
                    segments: sorted.asMap().entries.map((me) {
                      final idx = me.key;
                      final entry = me.value;
                      final color = AppConstants
                          .chartColors[idx % AppConstants.chartColors.length];
                      return PieChartSegment(
                        label: entry.key,
                        value: _animatePieIn ? entry.value : 0,
                        color: color,
                        isSelected: !_hiddenCategories.contains(entry.key),
                      );
                    }).toList(),
                    centerBuilder: (context, total) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Formatters.currency(total),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total Expense',
                            style: TextStyle(
                              color: AppConstants.greyText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (legendRows.length > 6)
          SizedBox(
            height: 340,
            child: Scrollbar(
              controller: _legendScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _legendScrollController,
                itemCount: legendRows.length,
                itemBuilder: (context, index) => legendRows[index],
              ),
            ),
          )
        else
          ...legendRows,
      ],
    );
  }

  Widget _buildLineView(List<Transaction> filteredTx) {
    if (filteredTx.isEmpty) return const SizedBox();

    final now = DateTime.now();

    List<Transaction> chartTx = [];
    if (_lineChartRange == 'Weekly') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      chartTx = filteredTx.where((tx) => tx.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) && tx.date.isBefore(startOfWeek.add(const Duration(days: 7)))).toList();
    } else if (_lineChartRange == '2 Weeks') {
      final startOfLastWeek = now.subtract(Duration(days: now.weekday - 1 + 7));
      chartTx = filteredTx.where((tx) => tx.date.isAfter(startOfLastWeek.subtract(const Duration(days: 1))) && tx.date.isBefore(startOfLastWeek.add(const Duration(days: 14)))).toList();
    } else { // Monthly
      chartTx = filteredTx.where((tx) => tx.date.year == now.year).toList();
    }

    Map<int, double> expensesByGroup = {};

    for (var tx in chartTx) {
      if (!tx.isExpense) continue;
      int groupKey;
      if (_lineChartRange == 'Weekly') {
        groupKey = tx.date.weekday;
      } else if (_lineChartRange == '2 Weeks') {
        final startOfLastWeek = now.subtract(Duration(days: now.weekday - 1 + 7));
        groupKey = tx.date.difference(startOfLastWeek).inDays + 1;
      } else {
        groupKey = tx.date.month;
      }
      expensesByGroup[groupKey] = (expensesByGroup[groupKey] ?? 0.0) + tx.debit;
    }

    List<FlSpot> spots = [];
    double maxAmount = 0;

    int maxGroup = _lineChartRange == 'Monthly' ? 12 : (_lineChartRange == '2 Weeks' ? 14 : 7);
    for (int i = 1; i <= maxGroup; i++) {
      double amount = expensesByGroup[i] ?? 0.0;
      if (amount > maxAmount) maxAmount = amount;
      spots.add(FlSpot(i.toDouble(), amount));
    }

    if (maxAmount == 0) maxAmount = 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Range selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['Weekly', '2 Weeks', 'Monthly'].map((range) {
            final isSelected = _lineChartRange == range;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChipWidget(
                label: range,
                isSelected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _lineChartRange = range);
                  }
                },
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: AnimatedLineChart(
            chartData: LineChartData(
              gridData: const FlGridData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withAlpha(220)
                      : Colors.black.withAlpha(220),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        Formatters.currency(spot.y),
                        TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      int intValue = value.toInt();
                      String text = '';
                      if (_lineChartRange == 'Monthly') {
                        if (intValue >= 1 && intValue <= 12) {
                          text = AppConstants.monthNames[intValue].substring(0, 3);
                        }
                      } else if (_lineChartRange == 'Weekly') {
                        switch (intValue) {
                          case 1: text = 'M'; break;
                          case 2: text = 'T'; break;
                          case 3: text = 'W'; break;
                          case 4: text = 'T'; break;
                          case 5: text = 'F'; break;
                          case 6: text = 'S'; break;
                          case 7: text = 'S'; break;
                        }
                      } else if (_lineChartRange == '2 Weeks') {
                        if (intValue % 2 != 0) {
                          text = intValue.toString();
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(text, style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 1,
              maxX: maxGroup.toDouble(),
              minY: 0,
              maxY: maxAmount * 1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: AppConstants.primaryPurple,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppConstants.primaryPurple.withAlpha(30),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '$_lineChartRange Expenses',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppConstants.greyText),
          ),
        ),
      ],
    );
  }
}

class ChoiceChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const ChoiceChipWidget({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppConstants.primaryPurple.withAlpha(50),
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? AppConstants.primaryPurple : Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppConstants.primaryPurple : Colors.grey.withAlpha(80),
        ),
      ),
    );
  }
}
