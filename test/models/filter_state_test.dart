import 'package:flutter_test/flutter_test.dart';
import 'package:x_pense/models/filter_state.dart';

void main() {
  group('FilterState', () {
    test('copyWith updates individual fields', () {
      const state = FilterState();

      final updatedType = state.copyWith(typeFilter: 'Income');
      expect(updatedType.typeFilter, 'Income');
      expect(updatedType.monthFilter, 'All');

      final updatedMonth = state.copyWith(monthFilter: 'Jan');
      expect(updatedMonth.monthFilter, 'Jan');
      expect(updatedMonth.typeFilter, 'All');

      final updatedYear = state.copyWith(yearFilter: '2025');
      expect(updatedYear.yearFilter, '2025');
      expect(updatedYear.typeFilter, 'All');

      final updatedCategory = state.copyWith(categoryFilter: 'Food');
      expect(updatedCategory.categoryFilter, 'Food');
      expect(updatedCategory.typeFilter, 'All');

      final updatedSearch = state.copyWith(searchQuery: 'Grocery');
      expect(updatedSearch.searchQuery, 'Grocery');
      expect(updatedSearch.typeFilter, 'All');
    });

    test('copyWith updates multiple fields at once', () {
      const state = FilterState();

      final updated = state.copyWith(
        typeFilter: 'Expense',
        monthFilter: 'Mar',
        yearFilter: '2024',
        categoryFilter: 'Transport',
        searchQuery: 'Uber',
      );

      expect(updated.typeFilter, 'Expense');
      expect(updated.monthFilter, 'Mar');
      expect(updated.yearFilter, '2024');
      expect(updated.categoryFilter, 'Transport');
      expect(updated.searchQuery, 'Uber');
    });

    test('copyWith returns identical state when no arguments provided', () {
      const state = FilterState(
        typeFilter: 'Expense',
        monthFilter: 'Feb',
        yearFilter: '2024',
        categoryFilter: 'Entertainment',
        searchQuery: 'Movie',
      );

      final unchanged = state.copyWith();

      expect(unchanged.typeFilter, 'Expense');
      expect(unchanged.monthFilter, 'Feb');
      expect(unchanged.yearFilter, '2024');
      expect(unchanged.categoryFilter, 'Entertainment');
      expect(unchanged.searchQuery, 'Movie');
    });
  });
}
