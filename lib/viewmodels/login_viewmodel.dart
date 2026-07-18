import 'package:flutter/foundation.dart';
import '../services/mock_data.dart';
import '../services/supabase_repository.dart';

/// ViewModel for the login screen.
/// Extracts authentication logic from _LoginScreenState._handleLogin().
class LoginViewModel extends ChangeNotifier {
  final SupabaseRepository _repo = SupabaseRepository();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Attempts to log in with [username] and [password] using Supabase.
  /// Returns an error message string on failure, or null on success.
  Future<String?> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      return 'Please enter both username and password.';
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repo.authenticateUser(username, password);

      if (result == null || result['success'] == false) {
        _isLoading = false;
        notifyListeners();
        return result?['message'] ?? 'Invalid username or password';
      }

      // Map Supabase role to app role
      final slotRole = result['role'] as String;
      String role;
      if (slotRole == 'superadmin') {
        role = 'Administrator';
      } else if (slotRole == 'admin') {
        role = 'Data Entry';
      } else {
        role = 'View-Only';
      }
      final adminArmyNo = result['army_no'] as String?;

      // Update MockDataManager session state for app compatibility
      MockDataManager().login(username, role, adminArmyNo: adminArmyNo);

      _isLoading = false;
      notifyListeners();
      return null; // success
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An error occurred. Please try again.';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
