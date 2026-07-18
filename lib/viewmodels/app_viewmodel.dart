import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ViewModel for the root app: controls splash visibility, login state,
/// and dark-mode theme. Extracted from _MyAppState in main.dart.
class AppViewModel extends ChangeNotifier {
  bool _showSplash = true;
  bool _isLoggedIn = false;
  bool _isDarkMode = false;

  bool get showSplash => _showSplash;
  bool get isLoggedIn => _isLoggedIn;
  bool get isDarkMode => _isDarkMode;

  AppViewModel() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  void onSplashFinished() {
    _showSplash = false;
    notifyListeners();
  }

  void onLoginSuccess() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void onLogout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
