import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tax_profile.dart';
import 'user_preferences.dart';
import 'app_logger.dart';

class TaxProfileService {
  static const String _tag = 'TaxProfileService';

  /// Get profile key based on current logged in user
  static Future<String?> _getProfileKey() async {
    final email = await UserPreferences.getEmail();
    if (email == null || email.isEmpty) return null;
    return 'tax_profile_${email.replaceAll('.', '_')}';
  }

  /// Get version history key
  static Future<String?> _getHistoryKey() async {
    final email = await UserPreferences.getEmail();
    if (email == null || email.isEmpty) return null;
    return 'tax_profile_history_${email.replaceAll('.', '_')}';
  }

  /// Get active tax profile
  static Future<TaxProfile> getProfile() async {
    try {
      final key = await _getProfileKey();
      if (key == null) return TaxProfile.defaultProfile();

      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(key);
      if (jsonStr == null) {
        // Save and return default profile if none exists
        final defaultProf = TaxProfile.defaultProfile();
        await saveProfile(defaultProf);
        return defaultProf;
      }

      return TaxProfile.fromJson(json.decode(jsonStr));
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to get tax profile', e, stack);
      return TaxProfile.defaultProfile();
    }
  }

  /// Save tax profile and append to version history
  static Future<void> saveProfile(TaxProfile profile) async {
    try {
      final key = await _getProfileKey();
      final historyKey = await _getHistoryKey();
      if (key == null || historyKey == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Get current profile to check if we are incrementing version
      final String? currentJson = prefs.getString(key);
      int newVersion = profile.version;
      if (currentJson != null) {
        try {
          final current = TaxProfile.fromJson(json.decode(currentJson));
          // If profile parameters changed, increment version
          if (current.professionType != profile.professionType ||
              current.taxRegime != profile.taxRegime ||
              current.businessCategory != profile.businessCategory ||
              current.expectedAnnualIncome != profile.expectedAnnualIncome ||
              current.businessType != profile.businessType ||
              current.deductions.getTotalDeductions() != profile.deductions.getTotalDeductions()) {
            newVersion = current.version + 1;
          }
        } catch (_) {}
      }

      final updatedProfile = profile.copyWith(version: newVersion);
      final jsonStr = json.encode(updatedProfile.toJson());
      await prefs.setString(key, jsonStr);

      // Save version history
      final List<String> history = prefs.getStringList(historyKey) ?? [];
      history.add(jsonStr);
      await prefs.setStringList(historyKey, history);

      AppLogger.info(_tag, 'Tax Profile saved successfully. Version: $newVersion');
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to save tax profile', e, stack);
    }
  }

  /// Get version history of profiles
  static Future<List<TaxProfile>> getProfileHistory() async {
    try {
      final historyKey = await _getHistoryKey();
      if (historyKey == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final List<String>? history = prefs.getStringList(historyKey);
      if (history == null) return [];

      return history
          .map((jsonStr) {
            try {
              return TaxProfile.fromJson(json.decode(jsonStr));
            } catch (_) {
              return null;
            }
          })
          .whereType<TaxProfile>()
          .toList();
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to get profile history', e, stack);
      return [];
    }
  }

  /// Reset profile to default
  static Future<void> resetProfile() async {
    try {
      final key = await _getProfileKey();
      final historyKey = await _getHistoryKey();
      
      final prefs = await SharedPreferences.getInstance();
      if (key != null) await prefs.remove(key);
      if (historyKey != null) await prefs.remove(historyKey);

      AppLogger.info(_tag, 'Tax Profile reset successfully.');
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to reset profile', e, stack);
    }
  }
}
