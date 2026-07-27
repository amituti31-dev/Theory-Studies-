import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  String _license = 'B';
  ThemeMode _themeMode = ThemeMode.light;

  String get license => _license;
  ThemeMode get themeMode => _themeMode;

  AppProvider() {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _license = prefs.getString('license') ?? 'B';
    _themeMode =
        (prefs.getBool('dark_mode') ?? false) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setLicense(String code) async {
    _license = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('license', code);
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _themeMode == ThemeMode.dark);
  }
}
