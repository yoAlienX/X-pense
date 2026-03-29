// viewmodels/transaction_viewmodel.dart
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../models/transaction.dart';
import '../models/filter_state.dart';
import '../services/storage_service.dart';

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

  // Getters
  List<Transaction> get allTransactions => List.unmodifiable(_allTransactions);
  List<Transaction> get filteredTransactions =>
      List.unmodifiable(_filteredTransactions);
  FilterState get filterState => _filterState;
  SelectionState get selectionState => _selectionState;
  bool get balanceVisible => _balanceVisible;
  bool get isLoading => _isLoading;
  List<String> get categories => List.unmodifiable(_categories);
  String get defaultCategory => _defaultCategory;

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

  // ==================== Initialization ====================

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
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

      // Apply initial filters
      _applyFilters();
    } catch (e) {
      print('Error initializing: $e');
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

    // Calculate running balance
    double runningBalance = 0.0;

    for (var txn in chronological) {
      // Update running balance: add credits, subtract debits
      runningBalance = runningBalance + txn.credit - txn.debit;
      txn.balance = runningBalance;
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

    // List is maintained newest-first where balance of first item is current.
    _currentBalance = _allTransactions.first.balance;
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
  Future<void> addMultipleTransactions(List<Transaction> transactions) async {
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
