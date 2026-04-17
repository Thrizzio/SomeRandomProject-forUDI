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
    user = await authService.currentUser();
    
    // If no active session, try to restore from saved email
    if (user == null) {
      final savedEmail = await UserPreferences.getEmail();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        // Restore user session from saved email
        user = AppUser(email: savedEmail);
      }
    } else {
      // Save current user email for persistence
      await UserPreferences.saveEmail(user!.email);
    }
    
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await authService.login(email, password);
      if (user != null) {
        await UserPreferences.saveEmail(user!.email);
      }
      return user != null;
    } catch (e) {
      error = e.toString();
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
      await authService.register(email, password);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await authService.logout();
    user = null;
    await UserPreferences.clearEmail();
    notifyListeners();
  }
}