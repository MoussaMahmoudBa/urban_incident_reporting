import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  Color get primaryColor => _isDarkMode ? const Color(0xFF1A237E) : const Color(0xFF1565C0);
  Color get accentColor => _isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1);
  Color get backgroundColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F9FF);
  Color get cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : Colors.grey[900]!;
  Color get secondaryTextColor => _isDarkMode ? Colors.white.withOpacity(0.9) : Colors.grey[800]!;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}