// This is a basic Flutter widget test.
//
// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:x_pense/main.dart';
import 'package:x_pense/services/storage_service.dart';

void main() {
  testWidgets('Expense Tracker app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ExpenseTrackerApp());

    // Splash and async initialization are animated; pump incrementally.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Filters').evaluate().isNotEmpty) {
        break;
      }
    }

    // Verify that the app title is present.
    expect(find.text('X-pense'), findsOneWidget);
  });
}
