import 'package:flutter_test/flutter_test.dart';
import 'package:x_pense/models/filter_state.dart';

void main() {
  group('SelectionState', () {
    test('initial state should be empty and not in selection mode', () {
      const state = SelectionState();

      expect(state.selectionMode, isFalse);
      expect(state.selectedIds, isEmpty);
      expect(state.selectedCount, equals(0));
      expect(state.isSelected('any_id'), isFalse);
    });

    group('toggleSelection', () {
      test('should add id when not present', () {
        const state = SelectionState();
        final newState = state.toggleSelection('id_1');

        expect(newState.selectedIds.contains('id_1'), isTrue);
        expect(newState.isSelected('id_1'), isTrue);
        expect(newState.selectedCount, equals(1));
        expect(newState.selectionMode, isTrue); // Should enter selection mode
      });

      test('should remove id when already present', () {
        const state = SelectionState(
          selectionMode: true,
          selectedIds: {'id_1'},
        );
        final newState = state.toggleSelection('id_1');

        expect(newState.selectedIds.contains('id_1'), isFalse);
        expect(newState.isSelected('id_1'), isFalse);
        expect(newState.selectedCount, equals(0));
        expect(newState.selectionMode, isFalse); // Should exit selection mode when empty
      });

      test('should maintain selection mode if other ids remain', () {
        const state = SelectionState(
          selectionMode: true,
          selectedIds: {'id_1', 'id_2'},
        );
        final newState = state.toggleSelection('id_1');

        expect(newState.selectedIds.contains('id_1'), isFalse);
        expect(newState.selectedIds.contains('id_2'), isTrue);
        expect(newState.selectedCount, equals(1));
        expect(newState.selectionMode, isTrue); // Selection mode remains true
      });

      test('multiple toggles should work correctly', () {
        var state = const SelectionState();

        // Add first
        state = state.toggleSelection('1');
        expect(state.selectedIds, equals({'1'}));
        expect(state.selectionMode, isTrue);

        // Add second
        state = state.toggleSelection('2');
        expect(state.selectedIds, equals({'1', '2'}));
        expect(state.selectionMode, isTrue);

        // Remove first
        state = state.toggleSelection('1');
        expect(state.selectedIds, equals({'2'}));
        expect(state.selectionMode, isTrue);

        // Remove second
        state = state.toggleSelection('2');
        expect(state.selectedIds, isEmpty);
        expect(state.selectionMode, isFalse);
      });
    });

    test('clearSelection should return empty state', () {
      const state = SelectionState(
        selectionMode: true,
        selectedIds: {'id_1', 'id_2'},
      );

      final newState = state.clearSelection();

      expect(newState.selectionMode, isFalse);
      expect(newState.selectedIds, isEmpty);
      expect(newState.selectedCount, equals(0));
    });

    test('selectAll should add all ids and enter selection mode', () {
      const state = SelectionState();
      final allIds = ['id_1', 'id_2', 'id_3'];

      final newState = state.selectAll(allIds);

      expect(newState.selectionMode, isTrue);
      expect(newState.selectedIds, equals({'id_1', 'id_2', 'id_3'}));
      expect(newState.selectedCount, equals(3));
    });

    test('copyWith should only update specified fields', () {
      const state = SelectionState();

      final newState = state.copyWith(selectionMode: true);
      expect(newState.selectionMode, isTrue);
      expect(newState.selectedIds, isEmpty); // Unchanged

      final newState2 = state.copyWith(selectedIds: {'id_1'});
      expect(newState2.selectionMode, isFalse); // Unchanged
      expect(newState2.selectedIds, equals({'id_1'}));
    });
  });

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
