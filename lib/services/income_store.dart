import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/parsed_income.dart';

class IncomeStore {
  static const String _kItems = 'tracked_incomes_v1';

  static Future<List<ParsedIncome>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kItems);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    final incomes = decoded
        .map((item) => ParsedIncome.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return incomes;
  }

  static Future<void> upsert(ParsedIncome income) async {
    final current = await loadAll();
    final exists = current.any((entry) => entry.dedupeKey == income.dedupeKey);

    if (exists) {
      return;
    }

    current.insert(0, income);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kItems,
      jsonEncode(current.map((entry) => entry.toJson()).toList()),
    );
  }
}
