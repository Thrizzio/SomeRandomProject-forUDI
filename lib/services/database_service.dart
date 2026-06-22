import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import 'user_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static const String _dbName = 'sms_transactions.db';
  static const int _version = 3;
  static const String _tableName = 'transactions';

  static Database? _database;

  // Web fallback storage
  static final List<Transaction> _webTransactions = [];
  static bool _webLoaded = false;

  static Future<void> _loadWebTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('web_transactions');
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr);
        _webTransactions.clear();
        _webTransactions.addAll(list.map((item) => Transaction.fromJson(item)));
      }
    } catch (e) {
      // ignore
    }
  }

  static Future<void> _saveWebTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = json.encode(_webTransactions.map((t) => t.toJson()).toList());
      await prefs.setString('web_transactions', jsonStr);
    } catch (e) {
      // ignore
    }
  }

  static Future<void> _ensureWebLoaded() async {
    if (!_webLoaded) {
      await _loadWebTransactions();
      _webLoaded = true;
    }
  }

  /// Get database instance
  static Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  /// Initialize database
  static Future<Database> _initDb() async {
    final String path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create table schema
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount TEXT NOT NULL,
        sender TEXT NOT NULL,
        messageBody TEXT NOT NULL,
        transactionType TEXT NOT NULL,
        date TEXT NOT NULL,
        userEmail TEXT,
        createdAt TEXT NOT NULL,
        classification TEXT,
        confidence REAL,
        source TEXT,
        UNIQUE(amount, sender, date, userEmail)
      )
    ''');
  }

  /// Handle database upgrade - Rebuild table with new UNIQUE constraint and add AI columns
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        try {
          // Create new table with userEmail column and updated UNIQUE constraint
          await txn.execute('''
            CREATE TABLE ${_tableName}_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount TEXT NOT NULL,
              sender TEXT NOT NULL,
              messageBody TEXT NOT NULL,
              transactionType TEXT NOT NULL,
              date TEXT NOT NULL,
              userEmail TEXT,
              createdAt TEXT NOT NULL,
              UNIQUE(amount, sender, date, userEmail)
            )
          ''');

          // Copy existing data from old table
          await txn.execute('''
            INSERT INTO ${_tableName}_new (
              id, amount, sender, messageBody, transactionType, date, userEmail, createdAt
            )
            SELECT
              id, amount, sender, messageBody, transactionType, date, NULL, createdAt
            FROM $_tableName
          ''');

          // Drop old table and rename new one
          await txn.execute('DROP TABLE $_tableName');
          await txn.execute('ALTER TABLE ${_tableName}_new RENAME TO $_tableName');
        } catch (e) {
          rethrow;
        }
      });
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN classification TEXT');
        await db.execute('ALTER TABLE $_tableName ADD COLUMN confidence REAL');
        await db.execute('ALTER TABLE $_tableName ADD COLUMN source TEXT');
      } catch (e) {
        // ignore
      }
    }
  }

  /// Insert transaction
  static Future<int> insertTransaction(Transaction transaction) async {
    try {
      final userEmail = await UserPreferences.getEmail();
      
      // Prevent inserting transaction without user email
      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('Cannot insert transaction: no user logged in');
      }

      if (kIsWeb) {
        await _ensureWebLoaded();
        // Prevent duplicate unique constraint: UNIQUE(amount, sender, date, userEmail)
        final duplicate = _webTransactions.any((t) =>
            t.amount == transaction.amount &&
            t.sender == transaction.sender &&
            t.date == transaction.date);
        if (!duplicate) {
          final id = _webTransactions.length + 1;
          final newTx = Transaction(
            id: id.toString(),
            amount: transaction.amount,
            sender: transaction.sender,
            messageBody: transaction.messageBody,
            transactionType: transaction.transactionType,
            date: transaction.date,
          );
          _webTransactions.add(newTx);
          await _saveWebTransactions();
          return id;
        }
        return 0;
      }
      
      final db = await database;
      final data = transaction.toJson();
      data['userEmail'] = userEmail;
      
      return await db.insert(
        _tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get all transactions for current user
  static Future<List<Transaction>> getAllTransactions() async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final list = List<Transaction>.from(_webTransactions);
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      }

      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'userEmail = ? OR userEmail IS NULL',
        whereArgs: [userEmail],
        orderBy: 'date DESC',
      );
      return maps.map((map) => Transaction.fromJson(map)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get transactions by type (income/expense) for current user
  static Future<List<Transaction>> getTransactionsByType(
      String transactionType) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final list = _webTransactions
            .where((t) => t.transactionType == transactionType)
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      }

      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'transactionType = ? AND (userEmail = ? OR userEmail IS NULL)',
        whereArgs: [transactionType, userEmail],
        orderBy: 'date DESC',
      );
      return maps.map((map) => Transaction.fromJson(map)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get transactions for date range for current user
  static Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final startIso = startDate.toIso8601String();
        final endIso = endDate.toIso8601String();
        final list = _webTransactions.where((t) {
          return t.date.compareTo(startIso) >= 0 && t.date.compareTo(endIso) <= 0;
        }).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      }

      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'date BETWEEN ? AND ? AND (userEmail = ? OR userEmail IS NULL)',
        whereArgs: [
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          userEmail,
        ],
        orderBy: 'date DESC',
      );
      return maps.map((map) => Transaction.fromJson(map)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get transaction count for current user
  static Future<int> getTransactionCount() async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        return _webTransactions.length;
      }

      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return 0;
      
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName WHERE userEmail = ? OR userEmail IS NULL', [userEmail]);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  /// Get total amount by type for current user
  static Future<double> getTotalAmountByType(String transactionType) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        double sum = 0.0;
        for (final t in _webTransactions) {
          if (t.transactionType == transactionType) {
            final cleaned = t.amount
                .replaceAll('₹', '')
                .replaceAll('Rs.', '')
                .replaceAll('Rs', '')
                .replaceAll(',', '')
                .replaceAll(' ', '')
                .trim();
            sum += double.tryParse(cleaned) ?? 0.0;
          }
        }
        return sum;
      }

      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return 0.0;
      
      final result = await db.rawQuery(
        '''
        SELECT SUM(
          CAST(
            REPLACE(
              REPLACE(
                REPLACE(
                  REPLACE(
                    REPLACE(amount, '₹', ''),
                  'Rs.', ''),
                'Rs', ''),
              ',', ''),
            ' ', '') AS REAL)
        ) as total
        FROM $_tableName
        WHERE transactionType = ? AND (userEmail = ? OR userEmail IS NULL)
        ''',
        [transactionType, userEmail],
      );
      final total = result.isNotEmpty ? result[0]['total'] : 0;
      return (total as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete transaction
  static Future<int> deleteTransaction(int id) async {
    try {
      if (kIsWeb) {
        await _ensureWebLoaded();
        final index = _webTransactions.indexWhere((t) => t.id == id.toString());
        if (index != -1) {
          _webTransactions.removeAt(index);
          await _saveWebTransactions();
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
      rethrow;
    }
  }

  /// Clear all transactions
  static Future<int> clearAllTransactions() async {
    try {
      if (kIsWeb) {
        _webTransactions.clear();
        await _saveWebTransactions();
        return 1;
      }

      final db = await database;
      return await db.delete(_tableName);
    } catch (e) {
      rethrow;
    }
  }

  /// Close database
  static Future<void> closeDatabase() async {
    if (kIsWeb) return;
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
