// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('Expense Tracker app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ExpenseTrackerApp());

    // Verify that the app title is present
    expect(find.text('Expense Tracker'), findsOneWidget);
    
    // Verify that the balance section is present
    expect(find.text('Current Balance'), findsOneWidget);
  });
}
