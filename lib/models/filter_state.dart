// models/filter_state.dart

class FilterState {
  final String typeFilter;    // 'All', 'Income', 'Expense'
  final String monthFilter;   // 'All', 'Jan', 'Feb', etc.
  final String yearFilter;    // 'All', '2024', '2025', etc.
  final String categoryFilter; // Category name or 'All'
  final String searchQuery;

  const FilterState({
    this.typeFilter = 'All',
    this.monthFilter = 'All',
    this.yearFilter = 'All',
    this.categoryFilter = 'All',
    this.searchQuery = '',
  });

  FilterState copyWith({
    String? typeFilter,
    String? monthFilter,
    String? yearFilter,
    String? categoryFilter,
    String? searchQuery,
  }) {
    return FilterState(
      typeFilter: typeFilter ?? this.typeFilter,
      monthFilter: monthFilter ?? this.monthFilter,
      yearFilter: yearFilter ?? this.yearFilter,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      typeFilter != 'All' ||
      monthFilter != 'All' ||
      yearFilter != 'All' ||
      categoryFilter != 'All' ||
      searchQuery.isNotEmpty;

  void clearFilters() {
    // Return new instance with all filters cleared
  }
}

class SelectionState {
  final bool selectionMode;
  final Set<String> selectedIds;

  const SelectionState({
    this.selectionMode = false,
    this.selectedIds = const {},
  });

  SelectionState copyWith({
    bool? selectionMode,
    Set<String>? selectedIds,
  }) {
    return SelectionState(
      selectionMode: selectionMode ?? this.selectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }

  bool isSelected(String id) => selectedIds.contains(id);
  
  int get selectedCount => selectedIds.length;

  SelectionState toggleSelection(String id) {
    final newIds = Set<String>.from(selectedIds);
    if (newIds.contains(id)) {
      newIds.remove(id);
    } else {
      newIds.add(id);
    }
    
    return copyWith(
      selectedIds: newIds,
      selectionMode: newIds.isNotEmpty,
    );
  }

  SelectionState clearSelection() {
    return const SelectionState();
  }

  SelectionState selectAll(List<String> allIds) {
    return SelectionState(
      selectionMode: true,
      selectedIds: Set<String>.from(allIds),
    );
  }
}
