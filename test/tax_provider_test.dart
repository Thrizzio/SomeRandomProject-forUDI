import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_parser_basically/models/tax_profile.dart';
import 'package:sms_parser_basically/models/transaction.dart';
import 'package:sms_parser_basically/providers/tax_provider.dart';
import 'package:sms_parser_basically/services/user_preferences.dart';
import 'package:sms_parser_basically/services/database_service.dart';

void main() {
  setUp(() async {
    // Mock shared preferences and force web fallback for tests
    SharedPreferences.setMockInitialValues({});
    DatabaseService.useWebFallback = true;
    await UserPreferences.saveEmail('test@freelancer.com');
    await DatabaseService.clearAllTransactions();
  });

  group('TaxProvider Unit & Integration Tests', () {
    test('Initializes with default profile and empty transactions', () async {
      final provider = TaxProvider();
      await provider.init();

      expect(provider.loading, isFalse);
      expect(provider.profile.professionType, equals('freelancer'));
      expect(provider.transactions, isEmpty);
      expect(provider.totalIncome, equals(0.0));
      expect(provider.totalExpenses, equals(0.0));
    });

    test('Computes totalIncome and totalExpenses accurately filtering types', () async {
      final provider = TaxProvider();
      await provider.init();

      final tx1 = Transaction(
        amount: '1,50,000 INR',
        sender: 'Upwork',
        messageBody: 'Payment received',
        transactionType: 'income',
        date: '2026-06-20T10:00:00Z',
      );
      final tx2 = Transaction(
        amount: '₹5,000',
        sender: 'Uber',
        messageBody: 'Commission deduction',
        transactionType: 'expense',
        date: '2026-06-21T12:00:00Z',
      );
      final tx3 = Transaction(
        amount: '50000',
        sender: 'Toptal',
        messageBody: 'Consulting fee',
        transactionType: 'credit',
        date: '2026-06-22T08:00:00Z',
      );
      final tx4 = Transaction(
        amount: '1000',
        sender: 'Airtel',
        messageBody: 'Internet bill',
        transactionType: 'debit',
        date: '2026-06-22T09:00:00Z',
      );

      // Save transactions locally via DatabaseService
      await DatabaseService.insertTransaction(tx1);
      await DatabaseService.insertTransaction(tx2);
      await DatabaseService.insertTransaction(tx3);
      await DatabaseService.insertTransaction(tx4);

      // Re-fetch transactions
      await provider.fetchTransactions();

      // Validate total income & expense getters
      expect(provider.transactions.length, equals(4));
      expect(provider.totalIncome, equals(200000.0)); // 150,000 + 50,000
      expect(provider.totalExpenses, equals(6000.0)); // 5,000 + 1,000
    });

    test('Calculates correct presumptive taxes and advance tax installments', () async {
      final provider = TaxProvider();
      await provider.init();

      final tx1 = Transaction(
        amount: '20,00,000 INR',
        sender: 'Client',
        messageBody: 'Project milestones',
        transactionType: 'income',
        date: '2026-06-20T10:00:00Z',
      );
      final tx2 = Transaction(
        amount: '2,00,000 INR',
        sender: 'Office Rent',
        messageBody: 'Workspace rent',
        transactionType: 'expense',
        date: '2026-06-21T12:00:00Z',
      );

      await DatabaseService.insertTransaction(tx1);
      await DatabaseService.insertTransaction(tx2);

      await provider.fetchTransactions();

      final calc = provider.taxCalculationResult;
      // gross income = 20,00,000
      // expenses = 2,00,000
      // Sec 44ADA presumptive profit = 50% of 20,00,000 = 10,00,000
      // net taxable income = presumptive profit - expenses = 8,00,000
      expect(calc.grossIncome, equals(2000000.0));
      expect(calc.netTaxableIncome, equals(800000.0));

      // Slabs:
      // - Up to 3,00,000: Nil
      // - 3,00,001 to 7,00,000: 5% (i.e. 4L * 0.05 = 20,000)
      // - 7,00,001 to 10,00,000: 10% (i.e. 1L * 0.10 = 10,000)
      // Total tax before cess = 30,000
      // Cess = 4% of 30,000 = 1,200
      // Total tax due = 31,200
      expect(calc.totalTaxDue, equals(31200.0));

      // Verify advance tax installments calculation
      final installments = provider.advanceTaxInstallments;
      expect(installments.length, equals(4));
      // 1st installment cumulative amount = 31,200 * 0.15 = 4,680
      expect(installments[0]['cumulativeAmount'], equals(4680.0));
    });

    test('Runs What-If Simulations correctly u/s different regimes', () async {
      final provider = TaxProvider();
      await provider.init();

      final simResult = provider.simulateWhatIf(
        1500000.0, // Simulated Income
        TaxDeductions(section80C: 150000.0, section80D: 25000.0), // Simulated Deductions
      );

      expect(simResult['recommendedRegime'], isNotNull);
      expect(simResult['taxDifference'], isNotNull);
    });

    test('Generates dynamic alerts for advance tax requirements & compliance', () async {
      final provider = TaxProvider();
      await provider.init();

      // Setup high income to trigger advance tax reminder
      final tx = Transaction(
        amount: '35,00,000 INR',
        sender: 'Overseas Corp',
        messageBody: 'Retainer',
        transactionType: 'income',
        date: '2026-06-20T10:00:00Z',
      );
      await DatabaseService.insertTransaction(tx);
      await provider.fetchTransactions();

      final insights = provider.getDynamicInsights();
      // Must contain quarterly advance tax reminder
      final hasAdvanceTaxReminder = insights.any((ins) => ins.contains('quarterly Advance Tax payments'));
      expect(hasAdvanceTaxReminder, isTrue);
    });
   group('TaxHealthScore Calculation', () {
      test('Calculates valid Tax Health Score based on parameters', () async {
        final provider = TaxProvider();
        await provider.init();
        
        final score = await provider.getTaxHealthScore();
        expect(score, isNot(null));
        expect(score, greaterThanOrEqualTo(0));
        expect(score, lessThanOrEqualTo(100));
      });
    });
  });
}
