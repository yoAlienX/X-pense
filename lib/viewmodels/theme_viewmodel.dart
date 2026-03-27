// viewmodels/theme_viewmodel.dart
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeViewModel extends ChangeNotifier {
  final StorageService _storage = StorageService();

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadTheme() async {
    _isDarkMode = _storage.getThemePreference();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.saveThemePreference(_isDarkMode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final isDark = mode == ThemeMode.dark;
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      await _storage.saveThemePreference(_isDarkMode);
      notifyListeners();
    }
  }
}
