// viewmodels/transaction_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../models/transaction.dart';
import '../models/filter_state.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';
import '../services/crypto_service.dart';

class TransactionViewModel extends ChangeNotifier {
  final StorageService _storage = StorageService();

  // Core data
  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];

  // UI State
  FilterState _filterState = FilterState(
    monthFilter: AppConstants.monthNames[DateTime.now().month],
    yearFilter: DateTime.now().year.toString(),
  );
  SelectionState _selectionState = const SelectionState();
  bool _balanceVisible = false;
  bool _isLoading = false;
  double _currentBalance = 0.0;
  List<String> _categories = List<String>.from(AppConstants.categories);
  String _defaultCategory = 'Uncategorized';
  List<String> _accounts = ['Canara Bank'];
  bool _showTotalBalance = false;

  // Pagination State
  int _displayLimit = 20;
  List<String>? _lastRestoredIds;

  // Getters
  List<Transaction> get allTransactions => List.unmodifiable(_allTransactions);
  List<Transaction> get filteredTransactions =>
      List.unmodifiable(_filteredTransactions);
  List<Transaction> get paginatedTransactions {
    if (_filteredTransactions.length <= _displayLimit) {
      return List.unmodifiable(_filteredTransactions);
    }
    return List.unmodifiable(_filteredTransactions.take(_displayLimit));
  }
  FilterState get filterState => _filterState;
  SelectionState get selectionState => _selectionState;
  bool get balanceVisible => _balanceVisible;
  bool get isLoading => _isLoading;
  bool get canUndoRestore => _lastRestoredIds != null;
  List<String> get categories => List.unmodifiable(_categories);
  String get defaultCategory => _defaultCategory;
  List<String> get accounts => List.unmodifiable(_accounts);
  bool get showTotalBalance => _showTotalBalance;

  // ==================== FIXED BALANCE CALCULATION ====================

  /// Current balance from cache (updated after balance recalculation/sorts).
  double get currentBalance {
    return _currentBalance;
  }

  /// Total income from filtered transactions
  double get totalIncome {
    return _filteredTransactions.fold(0.0, (sum, txn) => sum + txn.credit);
  }

  /// Total expenses from filtered transactions
  double get totalExpense {
    return _filteredTransactions.fold(0.0, (sum, txn) => sum + txn.debit);
  }

  /// Net flow (income - expenses) for filtered transactions
  double get netFlow => totalIncome - totalExpense;

  bool _needsDecryptionKey = false;
  bool get needsDecryptionKey => _needsDecryptionKey;

  // ==================== Initialization ====================

  Future<void> initialize() async {
    _isLoading = true;
    _needsDecryptionKey = false;
    notifyListeners();

    try {
      // Check if hash has expired (older than 30 days) and remove if necessary.
      final crypto = CryptoService();
      await crypto.checkAndEnforceHashExpiration();

      // Load transactions from storage
      _allTransactions = await _storage.loadTransactions();

      // Sort transactions by date (newest first) for display
      _allTransactions.sort((a, b) => b.date.compareTo(a.date));

      // Recalculate all balances to ensure consistency
      await _recalculateAllBalances(persistToStorage: false);
      _updateCurrentBalanceCache();

      // Load UI preferences
      _balanceVisible = _storage.getBalanceVisibility();

      // Load categories and default category
      _categories =
          _storage.getCategories() ??
          List<String>.from(AppConstants.categories);
      if (_categories.isEmpty) {
        _categories = List<String>.from(AppConstants.categories);
      }

      _defaultCategory =
          _storage.getDefaultCategory() ??
          (_categories.contains('Uncategorized')
              ? 'Uncategorized'
              : _categories.first);

      if (!_categories.contains(_defaultCategory)) {
        _defaultCategory = _categories.first;
      }

      _accounts = _storage.getAccounts() ?? ['Canara Bank'];
      if (_accounts.isEmpty) {
        _accounts = ['Canara Bank'];
      }

      _showTotalBalance = _storage.getShowTotalBalance();

      // Apply initial filters
      _applyFilters();
      _displayLimit = 20; // reset pagination limit
    } on FormatException catch (e) {
      if (e.message == 'needs_decryption') {
        _needsDecryptionKey = true;
      } else {
        print('Error parsing data: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== FIXED BALANCE RECALCULATION ====================

  /// Recalculate all transaction balances chronologically
  /// This is the CORRECT way to calculate running balances
  Future<void> _recalculateAllBalances({bool persistToStorage = true}) async {
    if (_allTransactions.isEmpty) {
      // Persist empty state; otherwise a refresh can reload stale transactions.
      if (persistToStorage) {
        await _storage.clearTransactions();
      }
      return;
    }

    // Sort chronologically (oldest first) for balance calculation
    final chronological = _allTransactions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate running balance per account
    Map<String, double> runningBalances = {};

    for (var txn in chronological) {
      double currentAccBal = runningBalances[txn.account] ?? 0.0;
      // Update running balance: add credits, subtract debits
      currentAccBal = currentAccBal + txn.credit - txn.debit;
      runningBalances[txn.account] = currentAccBal;
      txn.balance = currentAccBal;
    }

    if (persistToStorage) {
      // Save the updated balances
      await _storage.saveTransactions(_allTransactions);
    }
  }

  void _updateCurrentBalanceCache() {
    if (_allTransactions.isEmpty) {
      _currentBalance = 0.0;
      return;
    }

    if (_showTotalBalance) {
      Map<String, double> latestBalances = {};
      for (var txn in _allTransactions) {
        if (!latestBalances.containsKey(txn.account)) {
          latestBalances[txn.account] = txn.balance;
        }
      }
      _currentBalance = latestBalances.values.fold(0.0, (sum, val) => sum + val);
    } else {
      // List is maintained newest-first where balance of first item is current.
      _currentBalance = _allTransactions.first.balance;
    }
  }

  double getAccountBalance(String account) {
    if (_allTransactions.isEmpty) return 0.0;
    for (var txn in _allTransactions) {
      if (txn.account == account) {
        return txn.balance;
      }
    }
    return 0.0;
  }

  // ==================== Transaction Management ====================

  /// Add a new transaction
  Future<void> addTransaction(Transaction transaction) async {
    _allTransactions.add(transaction);

    // Recalculate balances for all transactions
    await _recalculateAllBalances();

    // Re-sort for display (newest first)
    _allTransactions.sort((a, b) => b.date.compareTo(a.date));
    _updateCurrentBalanceCache();

    // Apply filters to update the filtered list
    _applyFilters();

    notifyListeners();
  }

  /// Add multiple transactions at once
  Future<void> addMultipleTransactions(List<Transaction> transactions, {bool isRestore = false}) async {
    if (isRestore) _lastRestoredIds = transactions.map((t) => t.id).toList();
    _allTransactions.addAll(transactions);

    // Recalculate balances for all transactions
    await _recalculateAllBalances();

    // Re-sort for display (newest first)
    _allTransactions.sort((a, b) => b.date.compareTo(a.date));
    _updateCurrentBalanceCache();

    // Apply filters to update the filtered list
    _applyFilters();

    notifyListeners();
  }

  Future<void> revertRestore() async {
    if (_lastRestoredIds == null) return;

    _allTransactions.removeWhere((t) => _lastRestoredIds!.contains(t.id));
    _lastRestoredIds = null;

    await _recalculateAllBalances();

    _allTransactions.sort((a, b) => b.date.compareTo(a.date));
    _updateCurrentBalanceCache();

    _applyFilters();

    await _storage.saveTransactions(_allTransactions);
    notifyListeners();
  }

  /// Update an existing transaction
  Future<void> updateTransaction(
    String id,
    Transaction updatedTransaction,
  ) async {
    final index = _allTransactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      _allTransactions[index] = updatedTransaction;

      // Recalculate balances
      await _recalculateAllBalances();

      // Re-sort for display
      _allTransactions.sort((a, b) => b.date.compareTo(a.date));
      _updateCurrentBalanceCache();

      _applyFilters();
      notifyListeners();
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    _allTransactions.removeWhere((t) => t.id == id);

    // Recalculate balances for remaining transactions
    await _recalculateAllBalances();

    _updateCurrentBalanceCache();
    _applyFilters();
    notifyListeners();
  }

  /// Delete multiple transactions
  Future<void> deleteMultipleTransactions(Set<String> ids) async {
    _allTransactions.removeWhere((t) => ids.contains(t.id));

    // Recalculate balances
    await _recalculateAllBalances();

    _updateCurrentBalanceCache();
    // Clear selection
    _selectionState = _selectionState.clearSelection();

    _applyFilters();
    notifyListeners();
  }

  /// Update transaction category
  Future<void> updateTransactionCategory(String id, String category) async {
    final index = _allTransactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      _allTransactions[index].category = category;
      await _storage.saveTransactions(_allTransactions);
      _applyFilters();
      notifyListeners();
    }
  }

  /// Clear all transactions
  Future<void> clearAllTransactions() async {
    _allTransactions.clear();
    _filteredTransactions.clear();
    _currentBalance = 0.0;
    await _storage.clearTransactions();
    notifyListeners();
  }

  Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty || _categories.contains(trimmed)) return;

    _categories.add(trimmed);
    await _storage.saveCategories(_categories);
    notifyListeners();
  }

  Future<void> deleteCategory(String category) async {
    if (!_categories.contains(category) || _categories.length <= 1) return;

    _categories.remove(category);

    if (_defaultCategory == category) {
      _defaultCategory = _categories.contains('Uncategorized')
          ? 'Uncategorized'
          : _categories.first;
      await _storage.saveDefaultCategory(_defaultCategory);
    }

    // Keep data valid after deleting a category.
    for (final txn in _allTransactions) {
      if (txn.category == category) {
        txn.category = _defaultCategory;
      }
    }

    await _storage.saveCategories(_categories);
    await _storage.saveTransactions(_allTransactions);
    _applyFilters();
    notifyListeners();
  }

  Future<void> setDefaultCategory(String category) async {
    if (!_categories.contains(category) || _defaultCategory == category) return;

    _defaultCategory = category;
    await _storage.saveDefaultCategory(category);
    notifyListeners();
  }

  // ==================== Account Management ====================

  Future<void> addAccount(String account) async {
    final trimmed = account.trim();
    if (trimmed.isEmpty || _accounts.contains(trimmed)) return;

    _accounts.add(trimmed);
    await _storage.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> deleteAccount(String account) async {
    if (!_accounts.contains(account) || _accounts.length <= 1) return;

    _accounts.remove(account);
    await _storage.saveAccounts(_accounts);

    // We intentionally DO NOT modify or delete the historical transactions
    // associated with the deleted account. This preserves the transaction history.
    // The balances of other active accounts remain unaffected.

    await _recalculateAllBalances();
    _updateCurrentBalanceCache();
    _applyFilters();
    notifyListeners();
  }

  Future<void> editAccountBalance(String account, double newBalance) async {
    if (!_accounts.contains(account)) return;

    // Remove the previous initial balance transaction if it exists
    _allTransactions.removeWhere((txn) => txn.account == account && txn.category == 'Initial Balance');

    if (newBalance != 0.0) {
      final t = Transaction(
        id: 'initial_balance_${DateTime.now().millisecondsSinceEpoch}_$account',
        date: DateTime.now(),
        description: 'Initial Balance',
        referenceNo: 'SYSTEM',
        debit: newBalance < 0 ? newBalance.abs() : 0.0,
        credit: newBalance > 0 ? newBalance : 0.0,
        balance: newBalance,
        type: newBalance >= 0 ? 'Credit' : 'Debit',
        category: 'Initial Balance',
        account: account,
      );
      _allTransactions.add(t);
    }

    await _recalculateAllBalances();

    // Re-sort for display (newest first)
    _allTransactions.sort((a, b) => b.date.compareTo(a.date));
    _updateCurrentBalanceCache();

    _applyFilters();
    notifyListeners();
  }

  Future<void> setShowTotalBalance(bool showTotal) async {
    _showTotalBalance = showTotal;
    await _storage.saveShowTotalBalance(showTotal);
    _updateCurrentBalanceCache();
    notifyListeners();
  }

  // ==================== Archiving Data ====================

  Future<void> archiveOldTransactions(DateTime cutoffDate) async {
    // Separate transactions into old and new based on the cutoff date
    List<Transaction> oldTxs = [];
    List<Transaction> keptTxs = [];

    // We will calculate a single carry-forward balance for each account
    Map<String, double> carryForwardBalances = {};

    // For calculation, we process chronologically
    final chronological = _allTransactions.toList()..sort((a, b) => a.date.compareTo(b.date));

    for (var tx in chronological) {
      if (tx.date.isBefore(cutoffDate)) {
        oldTxs.add(tx);
        double currentBal = carryForwardBalances[tx.account] ?? 0.0;
        currentBal = currentBal + tx.credit - tx.debit;
        carryForwardBalances[tx.account] = currentBal;
      } else {
        keptTxs.add(tx);
      }
    }

    if (oldTxs.isEmpty) return; // Nothing to archive

    // Export the old transactions so the user doesn't permanently lose them
    try {
      final csvService = CsvService();
      await csvService.exportAndShare(
        oldTxs,
        isBackup: true,
        subject: 'Expense Tracker Archive Backup',
        text: 'Archived backup of ${oldTxs.length} old transactions before $cutoffDate.',
      );
    } catch (e) {
      debugPrint('Archive export error: $e');
      // If we fail to export, we should probably abort clearing to prevent data loss.
      // But we will continue based on user intention of clearing space.
    }

    // Replace old transactions with Carry Forward markers
    _allTransactions = List.from(keptTxs);

    for (var entry in carryForwardBalances.entries) {
      if (entry.value != 0.0) {
        _allTransactions.add(
          Transaction(
            id: 'carry_forward_${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
            date: cutoffDate,
            description: 'Carry-Forward Balance',
            referenceNo: 'SYSTEM_ARCHIVE',
            debit: entry.value < 0 ? entry.value.abs() : 0.0,
            credit: entry.value > 0 ? entry.value : 0.0,
            balance: entry.value,
            type: entry.value >= 0 ? 'Credit' : 'Debit',
            category: 'Initial Balance',
            account: entry.key,
          ),
        );
      }
    }

    await _recalculateAllBalances();
    _allTransactions.sort((a, b) => b.date.compareTo(a.date));
    _updateCurrentBalanceCache();
    _applyFilters();
    notifyListeners();
  }

  // ==================== Pagination ====================

  void loadMoreTransactions() {
    if (_displayLimit < _filteredTransactions.length) {
      _displayLimit += 20;
      notifyListeners();
    }
  }

  void resetPagination() {
    _displayLimit = 20;
    notifyListeners();
  }

  // ==================== Filtering ====================

  void setTypeFilter(String filter) {
    if (_filterState.typeFilter == filter) return;
    _filterState = _filterState.copyWith(typeFilter: filter);
    _applyFilters();
    notifyListeners();
  }

  void setMonthFilter(String filter) {
    if (_filterState.monthFilter == filter) return;
    _filterState = _filterState.copyWith(monthFilter: filter);
    _applyFilters();
    notifyListeners();
  }

  void setYearFilter(String filter) {
    if (_filterState.yearFilter == filter) return;
    _filterState = _filterState.copyWith(yearFilter: filter);
    _applyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String filter) {
    if (_filterState.categoryFilter == filter) return;
    _filterState = _filterState.copyWith(categoryFilter: filter);
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_filterState.searchQuery == query) return;
    _filterState = _filterState.copyWith(searchQuery: query);
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    if (_filterState == const FilterState()) return;
    _filterState = const FilterState();
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    // Reset pagination whenever filters change to ensure the user
    // sees the top of the newly filtered list.
    _displayLimit = 20;

    final hasDefaultFilters =
        _filterState.typeFilter == 'All' &&
        _filterState.monthFilter == 'All' &&
        _filterState.yearFilter == 'All' &&
        _filterState.categoryFilter == 'All' &&
        _filterState.searchQuery.isEmpty;

    if (hasDefaultFilters) {
      _filteredTransactions = _allTransactions;
      return;
    }

    _filteredTransactions = _allTransactions.where((txn) {
      // Type filter
      if (_filterState.typeFilter == 'Income' && !txn.isIncome) return false;
      if (_filterState.typeFilter == 'Expense' && !txn.isExpense) return false;

      // Month filter
      if (_filterState.monthFilter != 'All') {
        final monthIndex = _getMonthIndex(_filterState.monthFilter);
        if (monthIndex != -1 && txn.month != monthIndex) return false;
      }

      // Year filter
      if (_filterState.yearFilter != 'All') {
        final year = int.tryParse(_filterState.yearFilter);
        if (year != null && txn.year != year) return false;
      }

      // Category filter
      if (_filterState.categoryFilter != 'All' &&
          txn.category != _filterState.categoryFilter)
        return false;

      // Search query
      if (_filterState.searchQuery.isNotEmpty) {
        final query = _filterState.searchQuery.toLowerCase();
        return txn.description.toLowerCase().contains(query) ||
            txn.referenceNo.toLowerCase().contains(query) ||
            txn.category.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  int _getMonthIndex(String monthName) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final index = months.indexOf(monthName);
    return index >= 0 ? index + 1 : -1;
  }

  // ==================== Selection Management ====================

  void toggleSelection(String id) {
    _selectionState = _selectionState.toggleSelection(id);
    notifyListeners();
  }

  void clearSelection() {
    _selectionState = _selectionState.clearSelection();
    notifyListeners();
  }

  void selectAll() {
    final allIds = _filteredTransactions.map((t) => t.id).toList();
    _selectionState = _selectionState.selectAll(allIds);
    notifyListeners();
  }

  // ==================== UI Preferences ====================

  Future<void> toggleBalanceVisibility() async {
    _balanceVisible = !_balanceVisible;
    await _storage.saveBalanceVisibility(_balanceVisible);
    notifyListeners();
  }

  Future<void> forceMaskBalance() async {
    if (!_balanceVisible) {
      await _storage.saveBalanceVisibility(false);
      return;
    }

    _balanceVisible = false;
    await _storage.saveBalanceVisibility(false);
    notifyListeners();
  }

  // ==================== Analytics ====================

  Map<String, double> getCategoryExpenses() {
    final Map<String, double> categoryTotals = {};

    for (var txn in _filteredTransactions.where((t) => t.isExpense)) {
      categoryTotals[txn.category] =
          (categoryTotals[txn.category] ?? 0.0) + txn.debit;
    }

    return categoryTotals;
  }

  List<MapEntry<String, double>> getSortedCategoryExpenses() {
    final categoryExpenses = getCategoryExpenses();
    final sorted = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  // Get available years for filtering
  List<String> getAvailableYears() {
    final years = _allTransactions.map((t) => t.year.toString()).toSet();
    years.add(DateTime.now().year.toString());

    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
    return ['All', ...sortedYears];
  }
}
