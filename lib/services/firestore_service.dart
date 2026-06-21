import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

/// Production-ready Firestore database service with fallback safety
class FirestoreService {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      AppLogger.warning('FirestoreService', 'Firestore is not initialized: $e');
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      AppLogger.warning('FirestoreService', 'FirebaseAuth is not initialized: $e');
      return null;
    }
  }

  /// Get current user ID
  String? get _userId {
    try {
      return _auth?.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Add transaction to Firestore
  Future<String> addTransaction(Transaction transaction) async {
    try {
      final db = _firestore;
      final userId = _userId;
      if (db == null || userId == null) {
        AppLogger.warning('FirestoreService', 'Cannot add transaction: Firebase not available');
        return '';
      }

      final docRef = await db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add({
        'amount': transaction.amount,
        'sender': transaction.sender,
        'messageBody': transaction.messageBody,
        'transactionType': transaction.transactionType,
        'date': transaction.date,
        'createdAt': DateTime.now().toIso8601String(),
      });

      return docRef.id;
    } catch (e) {
      AppLogger.error('FirestoreService', 'Failed to add transaction', e);
      return '';
    }
  }

  /// Get all transactions for current user
  Future<List<Transaction>> getTransactions() async {
    try {
      final db = _firestore;
      final userId = _userId;
      if (db == null || userId == null) {
        return [];
      }

      final snapshot = await db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson({
                ...doc.data(),
                'id': doc.id,
              });
            } catch (e) {
              AppLogger.error('FirestoreService', 'Error parsing transaction ${doc.id}', e);
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      AppLogger.error('FirestoreService', 'Failed to fetch transactions', e);
      return [];
    }
  }

  /// Get transactions by type
  Future<List<Transaction>> getTransactionsByType(String type) async {
    try {
      final db = _firestore;
      final userId = _userId;
      if (db == null || userId == null) {
        return [];
      }

      final snapshot = await db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('transactionType', isEqualTo: type)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson({
                ...doc.data(),
                'id': doc.id,
              });
            } catch (e) {
              AppLogger.error('FirestoreService', 'Error parsing transaction ${doc.id}', e);
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      AppLogger.error('FirestoreService', 'Failed to fetch transactions by type', e);
      return [];
    }
  }

  /// Get transactions by date range
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = _firestore;
      final userId = _userId;
      if (db == null || userId == null) {
        return [];
      }

      final snapshot = await db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('date',
              isGreaterThanOrEqualTo: startDate.toIso8601String(),
              isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson({
                ...doc.data(),
                'id': doc.id,
              });
            } catch (e) {
              AppLogger.error('FirestoreService', 'Error parsing transaction ${doc.id}', e);
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      AppLogger.error('FirestoreService', 'Failed to fetch transactions by date range', e);
      return [];
    }
  }

  /// Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      final db = _firestore;
      final userId = _userId;
      if (db == null || userId == null) {
        return;
      }

      await db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      AppLogger.error('FirestoreService', 'Failed to delete transaction', e);
    }
  }

  /// Get real-time stream of transactions
  Stream<List<Transaction>> getTransactionsStream() {
    final db = _firestore;
    final userId = _userId;
    if (db == null || userId == null) {
      return Stream.value([]);
    }

    return db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                return Transaction.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                });
              } catch (e) {
                AppLogger.error('FirestoreService', 'Error parsing transaction ${doc.id}', e);
                return null;
              }
            })
            .whereType<Transaction>()
            .toList())
        .transform(
          StreamTransformer<List<Transaction>, List<Transaction>>.fromHandlers(
            handleError: (error, stackTrace, sink) {
              AppLogger.error('FirestoreService', 'Error in transactions stream', error);
              sink.add(<Transaction>[]);
            },
          ),
        );
  }

  /// Save bank statement transactions in bulk
  Future<void> saveBankStatementTransactions(
    List<Transaction> transactions,
  ) async {
    try {
      final db = _firestore;
      final userId = _userId;
      if (db == null || userId == null) {
        return;
      }

      final batch = db.batch();
      final userDoc = db
          .collection('users')
          .doc(userId)
          .collection('transactions');

      for (final transaction in transactions) {
        final docRef = userDoc.doc();
        batch.set(docRef, {
          'amount': transaction.amount,
          'sender': transaction.sender,
          'messageBody': transaction.messageBody,
          'transactionType': transaction.transactionType,
          'date': transaction.date,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
    } catch (e) {
      AppLogger.error('FirestoreService', 'Failed to save bank statement transactions', e);
    }
  }
}
