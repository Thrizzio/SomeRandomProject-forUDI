import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_parser_basically/services/bank_statement_engine_v2.dart';

void main() {
  group('BankStatementEngineV2 Test Suite & Benchmarks', () {
    late String tempCsvPath;
    late String tempPdfTxtPath;

    setUp(() async {
      // Create a temporary directory for test statement files
      final tempDir = Directory.systemTemp.createTempSync('bank_statements');
      tempCsvPath = '${tempDir.path}/sbi_statement.csv';
      tempPdfTxtPath = '${tempDir.path}/hdfc_statement.txt';
    });

    tearDown(() {
      try {
        final csvFile = File(tempCsvPath);
        if (csvFile.existsSync()) csvFile.deleteSync();
        final txtFile = File(tempPdfTxtPath);
        if (txtFile.existsSync()) txtFile.deleteSync();
      } catch (_) {}
    });

    test('Parser correctly extracts 50+ CSV rows and auto-detects formats', () async {
      // 1. Generate 50+ CSV samples covering different formats, banks, and malformed rows
      final csvContent = StringBuffer();
      
      // Add CSV Header for SBI style
      csvContent.writeln('Txn Date,Particulars,Debit,Credit,Balance');
      
      // 30 Valid Credit Rows
      for (int i = 1; i <= 30; i++) {
        csvContent.writeln('20/06/2024,UPI-Swiggy Delivery Payout-$i,,${200.0 + i * 50},${10000.0 + i * 200}');
      }
      
      // 15 Debit Rows (should be filtered as they are debits, or parsed with isCredit: false)
      for (int i = 1; i <= 15; i++) {
        csvContent.writeln('21/06/2024,UPI-Spent at Store-$i,${50.0 + i * 10},,${9000.0 - i * 10}');
      }

      // 10 Malformed/Spam/Empty Rows (should be ignored safely)
      csvContent.writeln(',,,'); // Empty row
      csvContent.writeln('##########,Invalid Excel Date,,1000.00,11000.00'); // Garbled date
      csvContent.writeln('22/06/2024,No amount row,,,'); // No amount
      csvContent.writeln('22/06/2024,Zero amount row,,0.00,10000.00'); // Zero amount
      csvContent.writeln('23/06/2024,Malformed Numbers,,Rs. abc.00,10000.00'); // Corrupted amount

      final file = File(tempCsvPath);
      file.writeAsStringSync(csvContent.toString());

      // 2. Parse the CSV file
      final transactions = await BankStatementEngineV2.parseFile(tempCsvPath);

      // Verify the parser never crashed and processed rows correctly
      expect(transactions, isNotEmpty);
      expect(transactions.first.bank, equals('SBI'));

      // Validate credit counts
      final credits = transactions.where((tx) => tx.isCredit).toList();
      expect(credits.length, equals(30)); // Must extract exactly the 30 credits
      expect(credits.first.source, equals('Swiggy'));

      // Validate debit extraction
      final debits = transactions.where((tx) => !tx.isCredit).toList();
      expect(debits.length, equals(15));
    });

    test('Parser extracts 20+ PDF/text lines correctly', () async {
      // 1. Generate 20+ text statement lines
      final txtContent = StringBuffer();
      
      // Add 20 Credit & Debit text lines
      for (int i = 1; i <= 12; i++) {
        txtContent.writeln('20-06-2024\tTransfer from Swiggy Payout-$i\t${150.0 + i * 10}');
      }
      for (int i = 1; i <= 10; i++) {
        txtContent.writeln('21-06-2024\tDebit Card Spend-$i\t-${50.0 + i * 5}');
      }

      final file = File(tempPdfTxtPath);
      file.writeAsStringSync(txtContent.toString());

      // 2. Parse the file
      final transactions = await BankStatementEngineV2.parseFile(tempPdfTxtPath);

      expect(transactions, isNotEmpty);
      final credits = transactions.where((tx) => tx.isCredit).toList();
      expect(credits.length, equals(12));
      expect(credits.first.source, equals('Swiggy'));

      final debits = transactions.where((tx) => !tx.isCredit).toList();
      expect(debits.length, equals(10));
    });

    test('Benchmark: Parse 5000+ CSV rows under 5 seconds', () async {
      // 1. Generate 5000 rows
      final csvContent = StringBuffer();
      csvContent.writeln('Txn Date,Particulars,Amount,Balance');
      for (int i = 1; i <= 5000; i++) {
        csvContent.writeln('20/06/2024,Swiggy Payout-$i,${100.0 + (i % 10) * 50},12000.00');
      }

      final file = File(tempCsvPath);
      file.writeAsStringSync(csvContent.toString());

      // 2. Measure execution time
      final stopwatch = Stopwatch()..start();
      final transactions = await BankStatementEngineV2.parseFile(tempCsvPath);
      stopwatch.stop();

      print('Parsed 5000 rows in: ${stopwatch.elapsedMilliseconds} ms');
      expect(transactions.length, equals(5000));
      expect(stopwatch.elapsed.inSeconds, lessThan(5)); // Must complete under 5 seconds
    });
  });
}
