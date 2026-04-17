import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import 'user_preferences.dart';

class DatabaseService {
  static const String _dbName = 'sms_transactions.db';
  static const int _version = 2;
  static const String _tableName = 'transactions';

  static Database? _database;

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
        UNIQUE(amount, sender, date, userEmail)
      )
    ''');
  }

  /// Handle database upgrade
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN userEmail TEXT');
      } catch (e) {
        // Column might already exist, ignore
      }
    }
  }

  /// Insert transaction
  static Future<int> insertTransaction(Transaction transaction) async {
    try {
      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
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
      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'userEmail = ?',
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
      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'transactionType = ? AND userEmail = ?',
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
      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'date BETWEEN ? AND ? AND userEmail = ?',
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
      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return 0;
      
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName WHERE userEmail = ?', [userEmail]);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  /// Get total amount by type for current user
  static Future<double> getTotalAmountByType(String transactionType) async {
    try {
      final db = await database;
      final userEmail = await UserPreferences.getEmail();
      
      if (userEmail == null) return 0.0;
      
      final result = await db.rawQuery(
        'SELECT SUM(CAST(SUBSTR(amount, 2) AS REAL)) as total FROM $_tableName WHERE transactionType = ? AND userEmail = ?',
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
      final db = await database;
      return await db.delete(_tableName);
    } catch (e) {
      rethrow;
    }
  }

  /// Close database
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
