// main.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({Key? key}) : super(key: key);

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Use immediate state update for faster response
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.deepPurple,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          elevation: 2,
          color: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      home: ExpenseTrackerHome(onThemeToggle: _toggleTheme),
    );
  }
}

class Transaction {
  final String id;
  final DateTime date;
  final String description;
  final String referenceNo;
  final double debit;
  final double credit;
  final double balance;
  final String type;
  String category;

  Transaction({
    required this.id,
    required this.date,
    required this.description,
    required this.referenceNo,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.type,
    this.category = 'Uncategorized',
  });
}

class ExpenseTrackerHome extends StatefulWidget {
  final VoidCallback onThemeToggle;
  
  const ExpenseTrackerHome({Key? key, required this.onThemeToggle}) : super(key: key);

  @override
  State<ExpenseTrackerHome> createState() => _ExpenseTrackerHomeState();
}

class _ExpenseTrackerHomeState extends State<ExpenseTrackerHome> {
  List<Transaction> transactions = [];
  List<Transaction> filteredTransactions = [];
  String selectedFilter = 'All';
  String selectedMonth = 'All';
  String selectedYear = 'All';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  double globalBalance = 0.0;
  
  final List<String> categories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Bills & Utilities',
    'Entertainment',
    'Health',
    'Education',
    'ATM Withdrawal',
    'Transfer/UPI',
    'Salary/Income',
    'Investment',
    'Uncategorized',
  ];

  static const List<String> _monthNames = [
    'All', 'Jan', 'Feb', 'Mar', 'Apr', 'May',
    'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactionsFromStorage();
  }

  Future<void> _loadTransactionsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('transactions');
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          transactions = decoded.map((item) => Transaction(
            id: item['id'],
            date: DateTime.parse(item['date']),
            description: item['description'],
            referenceNo: item['referenceNo'],
            debit: item['debit'].toDouble(),
            credit: item['credit'].toDouble(),
            balance: item['balance'].toDouble(),
            type: item['type'],
            category: item['category'] ?? 'Uncategorized',
          )).toList();
          globalBalance = transactions.isNotEmpty ? transactions.last.balance : 0.0;
          _applyFilters();
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  Future<void> _saveTransactionsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = transactions.map((t) => {
        'id': t.id,
        'date': t.date.toIso8601String(),
        'description': t.description,
        'referenceNo': t.referenceNo,
        'debit': t.debit,
        'credit': t.credit,
        'balance': t.balance,
        'type': t.type,
        'category': t.category,
      }).toList();
      await prefs.setString('transactions', jsonEncode(data));
    } catch (e) {
      print('Error saving transactions: $e');
    }
  }

  void _recalculateBalances() {
    final sorted = transactions.toList()..sort((a, b) => a.date.compareTo(b.date));
    double running = 0.0;
    for (int i = 0; i < sorted.length; i++) {
      running += sorted[i].credit - sorted[i].debit;
      final t = sorted[i];
      final idx = transactions.indexWhere((e) => e.id == t.id);
      if (idx != -1) {
        transactions[idx] = Transaction(
          id: t.id,
          date: t.date,
          description: t.description,
          referenceNo: t.referenceNo,
          debit: t.debit,
          credit: t.credit,
          balance: running,
          type: t.type,
          category: t.category,
        );
      }
    }
  }

  Future<void> _reconcileAndSave() async {
    _recalculateBalances();
    globalBalance = transactions.isNotEmpty ? transactions.last.balance : 0.0;
    await _saveTransactionsToStorage();
  }

  void _applyFilters() {
    setState(() {
      filteredTransactions = transactions.where((t) {
        bool matchesType = selectedFilter == 'All' ||
            (selectedFilter == 'Debit' && t.debit > 0) ||
            (selectedFilter == 'Credit' && t.credit > 0) ||
            t.category == selectedFilter;
        
        bool matchesMonth = selectedMonth == 'All' ||
            _monthNames[t.date.month] == selectedMonth;
        
        bool matchesYear = selectedYear == 'All' ||
            t.date.year.toString() == selectedYear;
        
        return matchesType && matchesMonth && matchesYear;
      }).toList();
    });
  }

  List<String> _getAvailableYears() {
    final yearsSet = transactions.map((t) => t.date.year).toSet();
    yearsSet.add(DateTime.now().year);
    final years = yearsSet.toList()..sort();
    return ['All', ...years.map((y) => y.toString())];
  }

  Widget _buildSummaryCard(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${value.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _exportCSV() async {
    try {
      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No transactions to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [
        ['Date', 'Description', 'Reference', 'Debit', 'Credit', 'Balance', 'Type', 'Category'],
        ...transactions.map((t) => [
          DateFormat('dd-MM-yyyy').format(t.date),
          t.description,
          t.referenceNo,
          t.debit,
          t.credit,
          t.balance,
          t.type,
          t.category,
        ]).toList(),
      ];
      String csv = const ListToCsvConverter().convert(rows);
      
      // Save to temporary directory and share
      final directory = await getTemporaryDirectory();
      final fileName = 'expense_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Expense Tracker Export',
        text: 'Exported ${transactions.length} transactions',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV file ready to share!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Feature 6: Export all data as backup
  Future<void> _exportAllDataBackup() async {
    try {
      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No transactions to backup'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [
        ['Date', 'Description', 'Reference', 'Debit', 'Credit', 'Balance', 'Type', 'Category'],
        ...transactions.map((t) => [
          DateFormat('dd-MM-yyyy').format(t.date),
          t.description,
          t.referenceNo,
          t.debit,
          t.credit,
          t.balance,
          t.type,
          t.category,
        ]).toList(),
      ];
      String csv = const ListToCsvConverter().convert(rows);
      
      // Save to temporary directory and share
      final directory = await getTemporaryDirectory();
      final fileName = 'expense_tracker_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Expense Tracker Full Backup',
        text: 'Complete backup of ${transactions.length} transactions. You can import this file to restore your data.',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup ready! ${transactions.length} transactions'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAddTransactionDialog() {
    final _formKey = GlobalKey<FormState>();
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String type = 'Debit';
    String cat = categories.first;
    DateTime date = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Transaction'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 8),
                TextFormField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference')),
                const SizedBox(height: 8),
                TextFormField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(value: type, items: ['Debit', 'Credit'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) { if (v != null) setState(() => type = v); }),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(value: cat, items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setState(() => cat = v); }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => date = picked);
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(DateFormat('dd MMM yyyy').format(date)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final amount = double.tryParse(amtCtrl.text) ?? 0.0;
                final transaction = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  date: date,
                  description: descCtrl.text,
                  referenceNo: refCtrl.text,
                  debit: type == 'Debit' ? amount : 0.0,
                  credit: type == 'Credit' ? amount : 0.0,
                  balance: 0.0,
                  type: type,
                  category: cat,
                );
                setState(() {
                  final id = const Uuid().v4();
                  final newT = Transaction(
                    id: id,
                    date: transaction.date,
                    description: transaction.description,
                    referenceNo: transaction.referenceNo,
                    debit: transaction.debit,
                    credit: transaction.credit,
                    balance: 0.0,
                    type: transaction.type,
                    category: transaction.category,
                  );
                  transactions.insert(0, newT);
                  _recalculateBalances();
                  globalBalance = transactions.isNotEmpty ? transactions.last.balance : 0.0;
                  _reconcileAndSave();
                  _applyFilters();
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _autoCategorizTransaction(String description) {
    description = description.toLowerCase();
    
    if (description.contains('zomato') || description.contains('swiggy') || 
        description.contains('restaurant') || description.contains('food')) {
      return 'Food & Dining';
    } else if (description.contains('kerala st') || description.contains('bus') || 
               description.contains('petrol') || description.contains('uber') || 
               description.contains('ola')) {
      return 'Transportation';
    } else if (description.contains('amazon') || description.contains('flipkart') || 
               description.contains('shop')) {
      return 'Shopping';
    } else if (description.contains('jio') || description.contains('electricity') || 
               description.contains('water') || description.contains('sms charges')) {
      return 'Bills & Utilities';
    } else if (description.contains('movie') || description.contains('game')) {
      return 'Entertainment';
    } else if (description.contains('hospital') || description.contains('medical') || 
               description.contains('pharmacy') || description.contains('bismi med')) {
      return 'Health';
    } else if (description.contains('university') || description.contains('college') || 
               description.contains('school') || description.contains('udemy')) {
      return 'Education';
    } else if (description.contains('atm cash')) {
      return 'ATM Withdrawal';
    } else if (description.contains('transfer') || description.contains('upi cr') || 
               description.contains('upi dr')) {
      return 'Transfer/UPI';
    } else if (description.contains('salary') || description.contains('interest')) {
      return 'Salary/Income';
    }
    return 'Uncategorized';
  }

  Future<void> importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final input = file.readAsStringSync();
        List<List<dynamic>> csvData = const CsvToListConverter().convert(input);

        setState(() {
          transactions.clear();
          for (int i = 1; i < csvData.length; i++) {
            var row = csvData[i];
            try {
              DateTime date = DateFormat('dd-MM-yyyy').parse(row[0].toString());
              double debit = row[3].toString().isEmpty ? 0.0 : double.parse(row[3].toString());
              double credit = row[4].toString().isEmpty ? 0.0 : double.parse(row[4].toString());
              
              String autoCategory = _autoCategorizTransaction(row[1].toString());
              
              transactions.add(Transaction(
                id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
                date: date,
                description: row[1].toString(),
                referenceNo: row[2].toString(),
                debit: debit,
                credit: credit,
                balance: double.parse(row[5].toString()),
                type: row[6].toString(),
                category: autoCategory,
              ));
            } catch (e) {
              print('Error parsing row $i: $e');
            }
          }
          // After importing, recalculate balances and re-apply current filters
          _recalculateBalances();
          // store to persistent storage and update globalBalance
          globalBalance = transactions.isNotEmpty ? transactions.last.balance : 0.0;
          _reconcileAndSave();
          _applyFilters();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${transactions.length} transactions'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double getTotalExpense() {
    return transactions.fold(0.0, (sum, item) => sum + item.debit);
  }

  double getTotalIncome() {
    return transactions.fold(0.0, (sum, item) => sum + item.credit);
  }

  Map<String, double> getCategoryExpenses() {
    Map<String, double> categoryExpenses = {};
    for (var transaction in transactions) {
      if (transaction.debit > 0) {
        categoryExpenses[transaction.category] = 
            (categoryExpenses[transaction.category] ?? 0) + transaction.debit;
      }
    }
    return categoryExpenses;
  }


  @override
  Widget build(BuildContext context) {
    double totalExpense = filteredTransactions.fold(0.0, (sum, item) => sum + item.debit);
    double totalIncome = filteredTransactions.fold(0.0, (sum, item) => sum + item.credit);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Expense Tracker',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: widget.onThemeToggle,
              borderRadius: BorderRadius.circular(8),
              child: Icon(
                Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
                size: 20,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // Export options with popup menu (Feature 6)
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Export Options',
            onSelected: (value) {
              if (value == 'filtered') {
                _exportCSV();
              } else if (value == 'all') {
                _exportAllDataBackup();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filtered',
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_outlined),
                    SizedBox(width: 8),
                    Text('Export Filtered'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.backup_outlined),
                    SizedBox(width: 8),
                    Text('Export All (Backup)'),
                  ],
                ),
              ),
            ],
          ),
          // Import CSV in app bar
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Import CSV',
            onPressed: importCSV,
          ),
          // Analytics with custom icon color
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.amber),
            onPressed: () {
              if (transactions.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No transactions to analyze. Import or add transactions first.')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalyticsScreen(
                    transactions: transactions,
                    categoryExpenses: getCategoryExpenses(),
                  ),
                ),
              );
            },
          ),
          // Bulk delete when selection mode active
          if (_selectionMode) ...[
            // Select All checkbox
            Checkbox(
              value: _selectedIds.length == filteredTransactions.length && filteredTransactions.isNotEmpty,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIds.addAll(filteredTransactions.map((t) => t.id));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              tooltip: 'Delete selected',
              onPressed: () {
                if (_selectedIds.isEmpty) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete selected transactions?'),
                    content: Text('This will delete ${_selectedIds.length} transactions.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () {
                        setState(() {
                          transactions.removeWhere((t) => _selectedIds.contains(t.id));
                          _selectedIds.clear();
                          _selectionMode = false;
                          _reconcileAndSave();
                          _applyFilters();
                        });
                        Navigator.of(ctx).pop();
                      }, child: const Text('Delete')),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: PopScope(
        canPop: !_selectionMode,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _selectionMode) {
            setState(() {
              _selectionMode = false;
              _selectedIds.clear();
            });
          }
        },
        child: Column(
          children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF2C2C2C), const Color(0xFF3E3E3E)]
                    : [Colors.deepPurple, Colors.deepPurple.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${globalBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildSummaryCard('Income', totalIncome, Colors.green, Icons.arrow_downward),
                    const SizedBox(width: 16),
                    _buildSummaryCard('Expense', totalExpense, Colors.red, Icons.arrow_upward),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Select All Checkbox with animation (Feature 1)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _selectionMode
                          ? Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _selectedIds.length == filteredTransactions.length && filteredTransactions.isNotEmpty,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedIds.addAll(filteredTransactions.map((t) => t.id));
                                        } else {
                                          _selectedIds.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const Text('All', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Filters (Feature 5: Resized to fit in one line)
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedFilter,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        items: ['All', 'Debit', 'Credit', ...categories]
                            .map((filter) => DropdownMenuItem(value: filter, child: Text(filter, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedFilter = value;
                            });
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: selectedMonth,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          isDense: true,
                        ),
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        items: _monthNames.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              selectedMonth = v;
                            });
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: selectedYear,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          isDense: true,
                        ),
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        items: _getAvailableYears().map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              selectedYear = v;
                            });
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Import CSV to get started',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      return _buildTransactionCard(transaction);
                    },
                  ),
          ),
        ],
      ),
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _selectionMode ? const Offset(0, 2) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _selectionMode ? 0.0 : 1.0,
          child: _selectionMode
              ? const SizedBox.shrink()
              : FloatingActionButton.extended(
                  onPressed: _showAddTransactionDialog,
                  label: const Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                  backgroundColor: Colors.deepPurple.shade700,
                ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    bool isDebit = transaction.debit > 0;
    final selected = _selectedIds.contains(transaction.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onLongPress: () {
          setState(() {
            _selectionMode = true;
            if (_selectedIds.contains(transaction.id)) _selectedIds.remove(transaction.id);
            else _selectedIds.add(transaction.id);
          });
        },
                  onTap: () {
            if (_selectionMode) {
              setState(() {
                if (_selectedIds.contains(transaction.id)) _selectedIds.remove(transaction.id);
                else _selectedIds.add(transaction.id);
                // Exit selection mode if no items selected
                if (_selectedIds.isEmpty) {
                  _selectionMode = false;
                }
              });
            } else {
              _showTransactionDetails(transaction);
            }
          },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? Colors.blue.shade50 : (isDebit ? Colors.red.shade50 : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? Icons.check : (isDebit ? Icons.arrow_upward : Icons.arrow_downward),
                  color: selected ? Colors.blue : (isDebit ? Colors.red : Colors.green),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(transaction.date),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            transaction.category,
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '₹${isDebit ? transaction.debit.toStringAsFixed(2) : transaction.credit.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDebit ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    setState(() {
                      transactions.removeWhere((t) => t.id == transaction.id);
                      _recalculateBalances();
                      globalBalance = transactions.isNotEmpty ? transactions.last.balance : 0.0;
                      _reconcileAndSave();
                      _applyFilters();
                    });
                  } else if (value == 'edit') {
                    _showEditTransactionDialog(transaction);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTransactionDialog(Transaction t) {
    final _formKey = GlobalKey<FormState>();
    final descCtrl = TextEditingController(text: t.description);
    final refCtrl = TextEditingController(text: t.referenceNo);
    final amtCtrl = TextEditingController(text: (t.debit > 0 ? t.debit : t.credit).toString());
    String type = t.debit > 0 ? 'Debit' : 'Credit';
    String cat = t.category;
    DateTime date = t.date;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Transaction'),
        content: StatefulBuilder(builder: (context, setState) {
          return SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 8),
                    TextFormField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference')),
                    const SizedBox(height: 8),
                    TextFormField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(value: type, items: ['Debit', 'Credit'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) { if (v != null) setState(() => type = v); }),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(value: cat, items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setState(() => cat = v); }),
                    const SizedBox(height: 8),
                    // Show the currently selected date and allow tapping it to pick a new one
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('dd MMM yyyy').format(date)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = double.tryParse(amtCtrl.text) ?? 0.0;
              setState(() {
                final idx = transactions.indexWhere((e) => e.id == t.id);
                  if (idx != -1) {
                    transactions[idx] = Transaction(
                      id: t.id,
                      date: date,
                      description: descCtrl.text,
                      referenceNo: refCtrl.text,
                      debit: type == 'Debit' ? amount : 0.0,
                      credit: type == 'Credit' ? amount : 0.0,
                      balance: 0.0,
                      type: type,
                      category: cat,
                    );
                    // Reconcile and persist so globalBalance and per-transaction balances update
                    _reconcileAndSave();
                    _applyFilters();
                  }
              });
              Navigator.of(context).pop();
            }
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              _buildDetailRow('Description', transaction.description),
              _buildDetailRow('Date', DateFormat('dd MMM yyyy').format(transaction.date)),
              _buildDetailRow('Reference', transaction.referenceNo),
              _buildDetailRow('Amount', 
                '₹${(transaction.debit > 0 ? transaction.debit : transaction.credit).toStringAsFixed(2)}'),
              _buildDetailRow('Type', transaction.type),
              _buildDetailRow('Balance', '₹${transaction.balance.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: transaction.category,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: categories.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      transaction.category = value;
                    });
                    setModalState(() {});
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
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

class AnalyticsScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final Map<String, double> categoryExpenses;

  const AnalyticsScreen({
    Key? key,
    required this.transactions,
    required this.categoryExpenses,
  }) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const List<String> _monthNames = [
    'All', 'Jan', 'Feb', 'Mar', 'Apr', 'May',
    'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  
  String selectedMonth = '';
  String selectedYear = 'All';
  bool _isPieChartView = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    // Feature 7: Default to current month
    final now = DateTime.now();
    selectedMonth = _monthNames[now.month];
    selectedYear = now.year.toString();
  }

  List<Transaction> get filteredTransactions {
    return widget.transactions.where((t) {
      bool matchesMonth = selectedMonth == 'All' ||
          _monthNames[t.date.month] == selectedMonth;
      bool matchesYear = selectedYear == 'All' ||
          t.date.year.toString() == selectedYear;
      return matchesMonth && matchesYear;
    }).toList();
  }

  Map<String, double> get filteredCategoryExpenses {
    Map<String, double> expenses = {};
    for (var t in filteredTransactions) {
      if (t.debit > 0) {
        expenses[t.category] = (expenses[t.category] ?? 0) + t.debit;
      }
    }
    return expenses;
  }

  List<String> _getAvailableYears() {
    final yearsSet = widget.transactions.map((t) => t.date.year).toSet();
    yearsSet.add(DateTime.now().year);
    final years = yearsSet.toList()..sort();
    return ['All', ...years.map((y) => y.toString())];
  }

  void _toggleChartView() async {
    setState(() {
      _isAnimating = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _isPieChartView = !_isPieChartView;
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, double>> sortedExpenses = filteredCategoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double totalExpense = filteredCategoryExpenses.values.fold(0.0, (sum, val) => sum + val);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Feature 7: Month/Year filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: _monthNames.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          selectedMonth = v;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: _getAvailableYears().map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          selectedYear = v;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              // Feature 10: Pie chart toggle
                              IconButton(
                                icon: Icon(_isPieChartView ? Icons.bar_chart : Icons.pie_chart_outline),
                                onPressed: _toggleChartView,
                                tooltip: _isPieChartView ? 'Bar View' : 'Pie Chart',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (sortedExpenses.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No expenses in selected period'),
                              ),
                            )
                          else if (_isAnimating)
                            // Feature 10: Animated pie chart loading
                            Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 40),
                                  TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 800),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    builder: (context, double value, child) {
                                      return SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: CircularProgressIndicator(
                                          value: value,
                                          strokeWidth: 8,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.deepPurple.shade400,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Loading chart view...'),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            )
                          else if (_isPieChartView)
                            _buildPieChartView(sortedExpenses, totalExpense)
                          else
                            ...sortedExpenses.map((entry) {
                              double percentage = totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          '₹${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        minHeight: 8,
                                        backgroundColor: Colors.grey[200],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.deepPurple.shade400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryItem('Total Transactions', filteredTransactions.length.toString()),
                          _buildSummaryItem('Total Expenses', '₹${totalExpense.toStringAsFixed(2)}'),
                          if (filteredTransactions.where((t) => t.debit > 0).isNotEmpty)
                            _buildSummaryItem('Average per Transaction', 
                                '₹${(totalExpense / filteredTransactions.where((t) => t.debit > 0).length).toStringAsFixed(2)}'),
                          if (filteredTransactions.any((t) => t.debit > 0))
                            _buildSummaryItem('Highest Expense', 
                                '₹${filteredTransactions.map((t) => t.debit).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // Feature 10: Pie chart view
  Widget _buildPieChartView(List<MapEntry<String, double>> sortedExpenses, double totalExpense) {
    final colors = [
      Colors.deepPurple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
      Colors.lime,
      Colors.brown,
    ];

    return Column(
      children: [
        // Simple pie chart visualization using colored containers
        SizedBox(
          height: 200,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: PieChartPainter(sortedExpenses, totalExpense, colors),
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '₹${totalExpense.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Legend
        ...sortedExpenses.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final entry = mapEntry.value;
          final percentage = totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '₹${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

// Custom painter for pie chart
class PieChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> expenses;
  final double total;
  final List<Color> colors;

  PieChartPainter(this.expenses, this.total, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -90 * (3.14159 / 180); // Start from top

    for (int i = 0; i < expenses.length; i++) {
      final sweepAngle = (expenses[i].value / total) * 2 * 3.14159;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}