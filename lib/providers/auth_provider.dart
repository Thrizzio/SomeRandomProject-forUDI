import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/user_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService authService;

  AppUser? user;
  bool loading = false;
  String? error;

  AuthProvider({required this.authService});

  bool get isAuthenticated => user != null;

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      user = await authService.currentUser();

      if (user != null) {
        await UserPreferences.saveEmail(user!.email);
        return;
      }

      final savedEmail = await UserPreferences.getEmail();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        user = AppUser(
          id: savedEmail,
          email: savedEmail,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      error = 'Failed to restore session: $e';
      user = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      if (email.isEmpty || password.isEmpty) {
        error = 'Email and password are required';
        return false;
      }

      user = await authService.login(email, password);
      if (user != null) {
        await UserPreferences.saveEmail(user!.email);
        return true;
      }

      error = 'Login failed';
      return false;
    } catch (e) {
      error = e.toString();
      user = null;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      if (email.isEmpty || password.isEmpty) {
        error = 'Email and password are required';
        return false;
      }

      if (password.length < 6) {
        error = 'Password must be at least 6 characters';
        return false;
      }

      final newUser = await authService.register(email, password);
      if (newUser != null) {
        user = newUser;
        await UserPreferences.saveEmail(user!.email);
        return true;
      }

      error = 'Registration failed';
      return false;
    } catch (e) {
      error = e.toString();
      user = null;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      loading = true;
      await authService.logout();
      user = null;
      error = null;
      await UserPreferences.clearEmail();
    } catch (e) {
      error = 'Failed to logout: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
