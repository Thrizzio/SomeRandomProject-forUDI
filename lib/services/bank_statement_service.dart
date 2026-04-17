import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/bank_statement_transaction.dart';
import 'database_service.dart';

class BankStatementService {
  static const String _tableName = 'bank_statements';

  /// Get database instance (reuse from DatabaseService)
  static Future<Database> get database async {
    return DatabaseService.database;
  }

  /// Initialize bank statement table (called once during app setup)
  static Future<void> initBankStatementTable() async {
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
