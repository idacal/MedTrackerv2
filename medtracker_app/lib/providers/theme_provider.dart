import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'themeMode';
  ThemeMode _themeMode = ThemeMode.system; // Default to system

  ThemeMode get themeMode => _themeMode;
  
  // Helper to quickly check if dark mode is active (considering system setting)
  bool isDarkMode(BuildContext context) {
     if (_themeMode == ThemeMode.system) {
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
     } else {
        return _themeMode == ThemeMode.dark;
     }
  }

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themePrefKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners(); // Notify after loading initial theme
    print("Loaded ThemeMode: $_themeMode");
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return; // No change needed

    _themeMode = mode;
    notifyListeners(); // Notify UI of change

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, mode.index);
     print("Saved ThemeMode: $_themeMode");
  }
  
  // Convenience method for toggling between light and dark directly
   Future<void> toggleTheme(bool isCurrentlyDark) async {
     await setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
   }
} 