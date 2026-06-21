import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/bank_statement_transaction.dart';
import 'database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BankStatementService {
  static const String _tableName = 'bank_statements';

  // Web fallback storage
  static final List<BankStatementTransaction> _webStatements = [];
  static bool _webLoaded = false;

  static Future<void> _loadWebStatements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('web_bank_statements');
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr);
        _webStatements.clear();
        _webStatements.addAll(list.map((item) => BankStatementTransaction.fromJson(item)));
      }
    } catch (e) {
      // ignore
    }
  }

  static Future<void> _saveWebStatements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = json.encode(_webStatements.map((t) => t.toJson()).toList());
      await prefs.setString('web_bank_statements', jsonStr);
    } catch (e) {
      // ignore
    }
  }

  static Future<void> _ensureWebLoaded() async {
    if (!_webLoaded) {
      await _loadWebStatements();
      _webLoaded = true;
    }
  }

  /// Get database instance (reuse from DatabaseService)
  static Future<Database> get database async {
    return DatabaseService.database;
  }

  /// Initialize bank statement table (called once during app setup)
  static Future<void> initBankStatementTable() async {
    if (kIsWeb) return;
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId TEXT NOT NULL,
        organization TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        transactionDate TEXT NOT NULL,
        transactionType TEXT NOT NULL,
        uploadedAt TEXT NOT NULL,
        bankStatementFileName TEXT NOT NULL,
        UNIQUE(transactionId, organization, transactionDate)
      )
    ''');
  }

  /// Insert bank statement transaction
  static Future<int> insertBankStatementTransaction(
    BankStatementTransaction transaction,
  ) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final duplicate = _webStatements.any((t) =>
            t.transactionId == transaction.transactionId &&
            t.organization == transaction.organization &&
            t.transactionDate.isAtSameMomentAs(transaction.transactionDate));
        if (!duplicate) {
          final id = _webStatements.length + 1;
          final newTx = transaction.copyWith(id: id);
          _webStatements.add(newTx);
          await _saveWebStatements();
          return id;
        }
        return 0;
      }

      final db = await database;
      return await db.insert(
        _tableName,
        transaction.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      throw Exception('Failed to insert bank statement: $e');
    }
  }

  /// Get transactions filtered by organization
  static Future<List<BankStatementTransaction>> getTransactionsByOrganization(
    String organization,
  ) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final list = _webStatements.where((t) => t.organization == organization).toList();
        list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
        return list;
      }

      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'organization = ?',
        whereArgs: [organization],
        orderBy: 'transactionDate DESC',
      );
      return result
          .map((json) => BankStatementTransaction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  /// Get transactions by type (income/expense)
  static Future<List<BankStatementTransaction>> getTransactionsByType(
    String transactionType,
  ) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final list = _webStatements.where((t) => t.transactionType == transactionType).toList();
        list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
        return list;
      }

      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'transactionType = ?',
        whereArgs: [transactionType],
        orderBy: 'transactionDate DESC',
      );
      return result
          .map((json) => BankStatementTransaction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  /// Get all bank statement transactions
  static Future<List<BankStatementTransaction>> getAllTransactions() async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final list = List<BankStatementTransaction>.from(_webStatements);
        list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
        return list;
      }

      final db = await database;
      final result = await db.query(
        _tableName,
        orderBy: 'transactionDate DESC',
      );
      return result
          .map((json) => BankStatementTransaction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  /// Get unique organizations from bank statements
  static Future<List<String>> getUniqueOrganizations() async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final orgs = _webStatements.map((t) => t.organization).toSet().toList();
        orgs.sort();
        return orgs;
      }

      final db = await database;
      final result = await db.rawQuery(
        'SELECT DISTINCT organization FROM $_tableName ORDER BY organization',
      );
      return result.map((row) => row['organization'] as String).toList();
    } catch (e) {
      throw Exception('Failed to fetch organizations: $e');
    }
  }

  /// Delete transaction by id
  static Future<int> deleteTransaction(int id) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final index = _webStatements.indexWhere((t) => t.id == id);
        if (index != -1) {
          _webStatements.removeAt(index);
          await _saveWebStatements();
          return 1;
        }
        return 0;
      }

      final db = await database;
      return await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  /// Get total income from specific organization
  static Future<double> getTotalIncomeByOrganization(
    String organization,
  ) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        double sum = 0.0;
        for (final t in _webStatements) {
          if (t.organization == organization && t.transactionType == 'income') {
            sum += t.amount;
          }
        }
        return sum;
      }

      final db = await database;
      final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM $_tableName WHERE organization = ? AND transactionType = ?',
        [organization, 'income'],
      );
      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      throw Exception('Failed to calculate total: $e');
    }
  }
}
