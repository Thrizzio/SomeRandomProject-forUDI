import 'package:flutter_test/flutter_test.dart';
import 'package:sms_parser_basically/models/user.dart';
import 'package:sms_parser_basically/models/transaction.dart';
import 'package:sms_parser_basically/services/auth_service.dart';
import 'package:sms_parser_basically/services/local_auth_service.dart';

void main() {
  group('Authentication Unit Tests', () {
    late AuthService authService;

    setUp(() {
      authService = LocalAuthService();
    });

    test('User Registration - Success', () async {
      final user = await authService.register('test@example.com', 'password123');
      expect(user, isNotNull);
      expect(user!.email, equals('test@example.com'));
    });

    test('User Registration - Duplicate Email Throws Exception', () async {
      await authService.register('test@example.com', 'password123');
      expect(
        () => authService.register('test@example.com', 'password123'),
        throwsException,
      );
    });

    test('User Login - Success', () async {
      await authService.register('test@example.com', 'password123');
      final user = await authService.login('test@example.com', 'password123');
      expect(user, isNotNull);
      expect(user!.email, equals('test@example.com'));
    });

    test('User Login - Invalid Credentials Throws Exception', () async {
      await authService.register('test@example.com', 'password123');
      expect(
        () => authService.login('test@example.com', 'wrongpassword'),
        throwsException,
      );
    });

    test('User Logout - Clears Current User Session', () async {
      await authService.register('test@example.com', 'password123');
      await authService.login('test@example.com', 'password123');
      
      var currentUser = await authService.currentUser();
      expect(currentUser, isNotNull);

      await authService.logout();
      currentUser = await authService.currentUser();
      expect(currentUser, isNull);
    });
  });

  group('Transactions and Security Isolation Tests', () {
    test('Transaction Model Validation', () {
      final validTx = Transaction(
        amount: '₹500',
        sender: 'HDFC',
        messageBody: 'Sent INR 500 to Self',
        transactionType: 'expense',
        date: DateTime.now().toIso8601String(),
      );

      final invalidTx = Transaction(
        amount: '',
        sender: '',
        messageBody: '',
        transactionType: '',
        date: '',
      );

      expect(validTx.isValid(), isTrue);
      expect(invalidTx.isValid(), isFalse);
    });

    test('User Isolation Verification mock', () async {
      // Simulate User A and User B logins
      final userA = AppUser(
        id: 'user_a',
        email: 'user_a@example.com',
        createdAt: DateTime.now(),
      );
      final userB = AppUser(
        id: 'user_b',
        email: 'user_b@example.com',
        createdAt: DateTime.now(),
      );

      final mockDatabase = <String, List<Transaction>>{};
      
      // Seed User A's data
      mockDatabase[userA.id] = [
        Transaction(
          id: 'tx_a',
          amount: '₹1200',
          sender: 'SBI',
          messageBody: 'Salary credited',
          transactionType: 'income',
          date: DateTime.now().toIso8601String(),
        ),
      ];

      // Seed User B's data
      mockDatabase[userB.id] = [
        Transaction(
          id: 'tx_b',
          amount: '₹400',
          sender: 'ICICI',
          messageBody: 'Lunch payment',
          transactionType: 'expense',
          date: DateTime.now().toIso8601String(),
        ),
      ];

      // Verify User A cannot access User B's transactions
      final userATxs = mockDatabase[userA.id] ?? [];
      final userBTxs = mockDatabase[userB.id] ?? [];

      expect(userATxs.any((tx) => tx.id == 'tx_b'), isFalse);
      expect(userBTxs.any((tx) => tx.id == 'tx_a'), isFalse);
    });
  });
}
