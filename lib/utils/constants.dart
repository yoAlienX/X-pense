// utils/constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'X-pense';
  static const String appVersion = '1.0.0';

  // Categories
  static const List<String> categories = [
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

  // Month Names
  static const List<String> monthNames = [
    'All',
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

  // Filter Options
  static const List<String> typeFilters = ['All', 'Income', 'Expense'];

  // Colors from Figma Dark Theme Kit
  static const Color primaryPurple = Color(0xFF7F3DFF);
  static const Color incomeGreen = Color(0xFF00D09E);
  static const Color expenseRed = Color(0xFFFD3C4A);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0D0E0F);
  static const Color darkCard = Color(0xFF1C1C23);
  static const Color darkSurface = Color(0xFF292B2E);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF6F6F6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF1F1FA);

  // Text Colors
  static const Color darkText = Color(0xFF0D0E0F);
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color greyText = Color(0xFF91919F);

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF7F3DFF), // Purple
    Color(0xFFFD3C4A), // Red
    Color(0xFF00D09E), // Green
    Color(0xFFFCAC12), // Yellow
    Color(0xFF0077FF), // Blue
    Color(0xFFFF6B6B), // Light Red
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFFBE0B), // Orange
    Color(0xFF8338EC), // Violet
    Color(0xFF06FFA5), // Mint
    Color(0xFFFF006E), // Pink
    Color(0xFF3A86FF), // Sky Blue
  ];

  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 24.0;

  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Font Sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeNormal = 16.0;
  static const double fontSizeLarge = 18.0;
  static const double fontSizeXLarge = 24.0;
  static const double fontSizeXXLarge = 32.0;

  // Icon Sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  // Glass style tokens (shared for consistent app-wide appearance)
  static const int glassContainerAlpha = 150;
  static const int glassFillAlpha = 120;
  static const int glassPanelAlpha = 168;
  static const int glassBorderAlpha = 90;
  static const int glassShadowAlpha = 18;
  static const int glassFocusAlpha = 210;
}
