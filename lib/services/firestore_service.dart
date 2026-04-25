import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Production-ready Firestore database service
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Add transaction to Firestore
  Future<String> addTransaction(Transaction transaction) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final docRef = await _firestore
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
      throw Exception('Failed to add transaction: $e');
    }
  }

  /// Get all transactions for current user
  Future<List<Transaction>> getTransactions() async {
    try {
      final userId = _userId;
      if (userId == null) {
        return [];
      }

      final snapshot = await _firestore
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
              // Log but don't fail entire operation
              print('Error parsing transaction ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  /// Get transactions by type
  Future<List<Transaction>> getTransactionsByType(String type) async {
    try {
      final userId = _userId;
      if (userId == null) {
        return [];
      }

      final snapshot = await _firestore
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
              print('Error parsing transaction ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions by type: $e');
    }
  }

  /// Get transactions by date range
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final userId = _userId;
      if (userId == null) {
        return [];
      }

      final snapshot = await _firestore
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
              print('Error parsing transaction ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions by date range: $e');
    }
  }

  /// Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  /// Get real-time stream of transactions
  Stream<List<Transaction>> getTransactionsStream() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
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
                print('Error parsing transaction ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Transaction>()
            .toList())
        .handleError((error) {
          print('Error in transactions stream: $error');
          return [];
        });
  }

  /// Save bank statement transactions in bulk
  Future<void> saveBankStatementTransactions(
    List<Transaction> transactions,
  ) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final batch = _firestore.batch();
      final userDoc = _firestore
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
      throw Exception('Failed to save bank statement transactions: $e');
    }
  }
}
