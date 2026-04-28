import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/bank_statement_transaction.dart';
import 'app_logger.dart';

class BankStatementParser {
  static const String _tag = 'BankStatementParser';
  static const List<String> predefinedOrganizations = [
    'Swiggy',
    'Zomato',
    'Ola',
    'Zepto',
  ];

  /// Parse CSV file content with comprehensive error handling
  static Future<List<BankStatementTransaction>> parseCsvFile(
    String filePath,
    String organization,
    String fileName,
  ) async {
    try {
      if (filePath.isEmpty) {
        throw Exception('File path is empty');
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File not found: $filePath');
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        throw Exception('File is empty');
      }

      AppLogger.info(_tag, 'Parsing CSV file: $fileName');

      // Split by newlines to properly parse CSV
      final lines = contents.split('\n');
      AppLogger.debug(_tag, 'File has ${lines.length} lines');

      // Convert lines to rows using CSV parser
      final rows = <List<dynamic>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final row = const CsvToListConverter().convert(line);
          if (row.isNotEmpty) {
            rows.add(row[0]);
          }
        } catch (e) {
          AppLogger.warning(_tag, 'Could not parse line: $line');
          continue;
        }
      }

      if (rows.isEmpty || rows.length < 2) {
        AppLogger.warning(_tag, 'No data rows found in file');
        return [];
      }

      AppLogger.info(_tag, 'Parsed ${rows.length} rows from file');

      final transactions = <BankStatementTransaction>[];

      // Parse data rows (skip header at index 0)
      for (int i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];

          // Skip empty rows
          if (row.isEmpty || row.length < 3) {
            continue;
          }

          final transaction = _parseRow(row, i, organization, fileName);
          if (transaction != null) {
            transactions.add(transaction);
          }
        } catch (e) {
          AppLogger.warning(_tag, 'Error parsing row $i: $e');
          continue;
        }
      }

      AppLogger.info(_tag,
          'Successfully extracted ${transactions.length} transactions from $fileName');
      return transactions;
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to parse CSV file', e, stackTrace);
      return [];
    }
  }

  /// Parse a single row into a transaction
  static BankStatementTransaction? _parseRow(
    List<dynamic> row,
    int rowIndex,
    String organization,
    String fileName,
  ) {
    try {
      // Extract columns: [Date, Description, Amount]
      String dateStr = row[0].toString().trim();
      String description = row[1].toString().trim();
      String amountStr = row[2].toString().trim();

      // Skip if date is ########## (Excel formatting issue)
      if (dateStr.contains('#') || dateStr.isEmpty) {
        return null;
      }

      // Parse amount
      double amount = _parseAmount(amountStr);

      // Skip if amount is 0
      if (amount == 0) {
        return null;
      }

      // Parse date
      DateTime? transactionDate = _parseDate(dateStr);
      if (transactionDate == null) {
        AppLogger.warning(_tag, 'Could not parse date: $dateStr');
        return null;
      }

      // Ensure amount is positive
      amount = amount.abs();

      // Create transaction
      return BankStatementTransaction(
        transactionId:
            'TXN_${organization}_${rowIndex}_${transactionDate.millisecondsSinceEpoch}',
        organization: organization,
        amount: amount,
        description: description,
        transactionDate: transactionDate,
        transactionType: 'income',
        bankStatementFileName: fileName,
      );
    } catch (e) {
      AppLogger.warning(_tag, 'Error parsing row $rowIndex: $e');
      return null;
    }
  }

  /// Parse amount string and extract numeric value
  static double _parseAmount(String amountStr) {
    try {
      // Remove common currency symbols and whitespace
      String cleaned = amountStr
          .replaceAll('₹', '')
          .replaceAll('Rs', '')
          .replaceAll('Rs.', '')
          .replaceAll(',', '')
          .replaceAll(' ', '')
          .trim();

      // Remove any non-digit and non-decimal characters
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9.-]'), '');

      double? amount = double.tryParse(cleaned);
      return amount ?? 0.0;
    } catch (e) {
      AppLogger.debug(_tag, 'Could not parse amount: $amountStr');
      return 0.0;
    }
  }

  /// Try to parse date in various formats
  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty || dateStr.contains('#')) return null;

    final formats = [
      'M/d/yyyy', // 1/1/2024, 2/1/2024
      'MM/dd/yyyy', // 01/01/2024, 02/01/2024
      'd/M/yyyy', // 1/1/2024 (alternative)
      'dd/MM/yyyy', // 01/01/2024 (European)
      'yyyy/MM/dd', // 2024/01/01
      'yyyy-MM-dd', // 2024-01-01
      'dd MMM yyyy', // 01 Jan 2024
      'MMM dd, yyyy', // Jan 01, 2024
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateStr);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  /// Extract organization name from description
  static String extractOrganizationFromDescription(String description) {
    final lowerDesc = description.toLowerCase();

    for (final org in predefinedOrganizations) {
      if (lowerDesc.contains(org.toLowerCase())) {
        return org;
      }
    }

    return 'Other';
  }

  /// Filter transactions by organization name
  static List<BankStatementTransaction> filterByOrganization(
    List<BankStatementTransaction> transactions,
    String organization,
  ) {
    if (organization == 'All') {
      return transactions;
    }

    return transactions
        .where((t) => t.organization.toLowerCase() == organization.toLowerCase())
        .toList();
  }
}

