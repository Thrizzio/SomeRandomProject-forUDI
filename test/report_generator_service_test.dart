import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_parser_basically/models/tax_profile.dart';
import 'package:sms_parser_basically/models/transaction.dart';
import 'package:sms_parser_basically/services/report_generator_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getLibraryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return [Directory.systemTemp.path];
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return [Directory.systemTemp.path];
  }

  @override
  Future<String?> getDownloadsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  group('ReportGeneratorService PDF Suite', () {
    final transactions = [
      Transaction(
        amount: '1,50,000 INR',
        sender: 'Upwork',
        messageBody: 'Payment received',
        transactionType: 'income',
        date: '2026-06-20T10:00:00Z',
      ),
      Transaction(
        amount: '₹5,000',
        sender: 'Uber',
        messageBody: 'Commission deduction',
        transactionType: 'expense',
        date: '2026-06-21T12:00:00Z',
      ),
    ];

    test('Generates annual tax report PDF file successfully', () async {
      final file = await ReportGeneratorService.generatePdfReport(
        transactions: transactions,
        userEmail: 'freelancer@gigtax.in',
        totalIncome: 150000.0,
        taxableIncome: 75000.0,
        taxPayable: 0.0,
        totalExpenses: 5000.0,
        reportType: 'annual_tax',
        taxProfile: TaxProfile.defaultProfile(),
      );

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));

      // Cleanup
      try {
        file.deleteSync();
      } catch (_) {}
    });

    test('Generates quarterly advance tax report PDF file successfully', () async {
      final file = await ReportGeneratorService.generatePdfReport(
        transactions: transactions,
        userEmail: 'freelancer@gigtax.in',
        totalIncome: 150000.0,
        taxableIncome: 75000.0,
        taxPayable: 0.0,
        totalExpenses: 5000.0,
        reportType: 'quarterly_tax',
        taxProfile: TaxProfile.defaultProfile(),
      );

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));

      // Cleanup
      try {
        file.deleteSync();
      } catch (_) {}
    });

    test('Generates client revenue concentration report PDF file successfully', () async {
      final file = await ReportGeneratorService.generatePdfReport(
        transactions: transactions,
        userEmail: 'freelancer@gigtax.in',
        totalIncome: 150000.0,
        taxableIncome: 75000.0,
        taxPayable: 0.0,
        totalExpenses: 5000.0,
        reportType: 'client_revenue',
        taxProfile: TaxProfile.defaultProfile(),
      );

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));

      // Cleanup
      try {
        file.deleteSync();
      } catch (_) {}
    });
  });
}
