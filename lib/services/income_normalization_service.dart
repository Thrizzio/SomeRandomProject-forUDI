import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class IncomeNormalizationService {
  static const String _tag = 'IncomeNormalizationService';
  static const String _overridePrefsKey = 'normalization_overrides';

  // Persistent user overrides (raw source -> normalized source)
  static final Map<String, String> _userOverrides = {};
  static bool _loaded = false;

  /// Load persistent overrides
  static Future<void> loadOverrides() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_overridePrefsKey));
      for (final key in keys) {
        final raw = key.replaceFirst('$_overridePrefsKey:', '');
        final val = prefs.getString(key);
        if (val != null) {
          _userOverrides[raw] = val;
        }
      }
      _loaded = true;
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to load overrides: $e');
    }
  }

  /// Save a user override
  static Future<void> saveOverride(String rawSource, String normalizedSource) async {
    try {
      _userOverrides[rawSource] = normalizedSource;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_overridePrefsKey:$rawSource', normalizedSource);
      AppLogger.info(_tag, 'Saved normalization override: "$rawSource" -> "$normalizedSource"');
    } catch (e) {
      AppLogger.error(_tag, 'Failed to save override', e, StackTrace.current);
    }
  }

  /// Normalize a raw source name to a clean entity name
  static NormalizationResult normalize(String rawName) {
    final cleanRaw = rawName.trim();
    if (cleanRaw.isEmpty) {
      return NormalizationResult(normalized: 'Other', confidence: 0.0);
    }

    // Check user overrides first
    if (_userOverrides.containsKey(cleanRaw)) {
      return NormalizationResult(
        normalized: _userOverrides[cleanRaw]!,
        confidence: 1.0,
        isOverridden: true,
      );
    }

    final lower = cleanRaw.toLowerCase();

    // Built-in rule-based exact/substring groups
    final groups = {
      'Swiggy': ['swiggy', 'swigy', 'swiggi', 'swiggie', 'instamart', 'swiggy delivery'],
      'Zomato': ['zomato', 'zomto', 'zomata', 'blinkit', 'zomato delivery'],
      'Uber': ['uber', 'ubereats', 'uber driver', 'uber cabs'],
      'Ola': ['ola', 'olacabs', 'ola partner', 'ola electric'],
      'Zepto': ['zepto', 'zept'],
      'Rapido': ['rapido', 'rapid'],
      'Salary Account': ['salary', 'payroll', 'stipend', 'payout'],
    };

    for (final entry in groups.entries) {
      for (final trigger in entry.value) {
        if (lower.contains(trigger)) {
          return NormalizationResult(normalized: entry.key, confidence: 0.95);
        }
      }
    }

    // Try fuzzy match similarity with known entities
    final knownEntities = ['Swiggy', 'Zomato', 'Uber', 'Ola', 'Zepto', 'Rapido', 'Urban Company', 'Dunzo'];
    String bestMatch = 'Other';
    double bestScore = 0.0;

    for (final entity in knownEntities) {
      final score = _calculateSimilarity(lower, entity.toLowerCase());
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entity;
      }
    }

    // Return fuzzy match if confidence is above threshold
    if (bestScore >= 0.7) {
      return NormalizationResult(normalized: bestMatch, confidence: bestScore);
    }

    // Fallback: clean company suffixes (Pvt Ltd, Technologies, Solutions, Inc)
    final cleanCompany = cleanRaw
        .replaceAll(RegExp(r'\b(pvt|ltd|limited|private|solutions|technologies|inc|corp|co)\b', caseSensitive: false), '')
        .trim();

    return NormalizationResult(
      normalized: cleanCompany.isNotEmpty ? cleanCompany : 'Other',
      confidence: 0.5,
    );
  }

  /// Levenshtein Distance similarity score (0.0 to 1.0)
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final length1 = s1.length;
    final length2 = s2.length;

    final headers = List<int>.generate(length2 + 1, (i) => i);
    final current = List<int>.filled(length2 + 1, 0);

    for (int i = 0; i < length1; i++) {
      current[0] = i + 1;
      for (int j = 0; j < length2; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        current[j + 1] = min(
          min(current[j] + 1, headers[j + 1] + 1),
          headers[j] + cost,
        );
      }
      for (int j = 0; j <= length2; j++) {
        headers[j] = current[j];
      }
    }

    final distance = headers[length2];
    final maxLength = max(length1, length2);
    return 1.0 - (distance / maxLength);
  }
}

class NormalizationResult {
  final String normalized;
  final double confidence;
  final bool isOverridden;

  NormalizationResult({
    required this.normalized,
    required this.confidence,
    this.isOverridden = false,
  });
}
