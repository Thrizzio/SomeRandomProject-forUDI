import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/parsed_transaction.dart';
import 'app_logger.dart';

class BankStatementEngineV2 {
  static const String _tag = 'BankStatementEngineV2';

  /// Parse bank statement file contents (auto-detects format and bank schema)
  static Future<List<ParsedTransaction>> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File does not exist: $filePath');
      }

      final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
      final content = await file.readAsString();

      if (content.trim().isEmpty) {
        throw Exception('File is empty');
      }

      // Auto-detect format type: CSV or TXT/PDF text export
      if (fileName.endsWith('.csv') || content.contains(',') || content.contains(';')) {
        return _parseCsvContent(content, fileName);
      } else {
        return _parseTextContent(content, fileName);
      }
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to parse bank statement file', e, stackTrace);
      return [];
    }
  }

  /// Parse CSV bank statements
  static List<ParsedTransaction> _parseCsvContent(String content, String fileName) {
    try {
      final lines = content.split('\n');
      final rows = <List<dynamic>>[];
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final parsedLine = const CsvToListConverter(
            shouldParseNumbers: false,
            allowInvalid: true,
          ).convert(trimmed);
          if (parsedLine.isNotEmpty) {
            rows.add(parsedLine[0]);
          }
        } catch (e) {
          continue;
        }
      }

      if (rows.isEmpty) return [];

      // Detect Bank schema
      final bank = _detectBankFromHeaderOrFileName(rows, fileName);
      AppLogger.info(_tag, 'Detected bank schema: $bank for statement file: $fileName');

      // Find start of transaction rows and column mappings
      int headerRowIndex = _findHeaderRowIndex(rows);
      if (headerRowIndex == -1) {
        AppLogger.warning(_tag, 'Could not find header row in statement. Falling back to default mapping.');
        headerRowIndex = 0;
      }

      final colMapping = _getColumnMapping(rows[headerRowIndex]);
      final transactions = <ParsedTransaction>[];

      // Parse data rows
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.length < colMapping.minRequiredColumns) continue;

        try {
          final tx = _parseRow(row, i, colMapping, bank, fileName);
          if (tx != null) {
            transactions.add(tx);
          }
        } catch (e) {
          // Gracefully continue to next row on error
          AppLogger.debug(_tag, 'Error parsing row $i: $e');
        }
      }

      return transactions;
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'CSV parsing error', e, stackTrace);
      return [];
    }
  }

  /// Parse text/PDF exports where columns are tab-separated or space-separated
  static List<ParsedTransaction> _parseTextContent(String content, String fileName) {
    final lines = content.split('\n');
    final transactions = <ParsedTransaction>[];
    final bank = fileName.contains('sbi') ? 'SBI' : (fileName.contains('hdfc') ? 'HDFC' : 'Unknown');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Extract using space/tab splits or custom regexes
      final parts = line.split(RegExp(r'\s{2,}|,|\t'));
      if (parts.length >= 3) {
        final date = _parseDate(parts[0]);
        final amountStr = parts[parts.length - 1];
        final amountVal = _parseAmount(amountStr);
        
        if (date != null && amountVal.abs() > 0) {
          final desc = parts.sublist(1, parts.length - 1).join(' ');
          final isCredit = !desc.toLowerCase().contains('debit') && 
                           !desc.toLowerCase().contains('spent') && 
                           !amountStr.contains('-');
          final normalizedSource = _normalizeSource(desc);

          transactions.add(ParsedTransaction(
            amount: amountVal.abs(),
            sender: bank,
            platform: 'Bank Transfer',
            date: date,
            reference: 'TXT_REF_${i}_${date.millisecondsSinceEpoch}',
            bank: bank,
            rawMessage: line,
            isCredit: isCredit,
            confidence: 0.8,
            classification: isCredit ? 'Gig Income' : 'Other',
            source: normalizedSource,
          ));
        }
      }
    }
    return transactions;
  }

  /// Detect bank name from column header patterns or file name
  static String _detectBankFromHeaderOrFileName(List<List<dynamic>> rows, String fileName) {
    final lowerFileName = fileName.toLowerCase();
    if (lowerFileName.contains('sbi')) return 'SBI';
    if (lowerFileName.contains('hdfc')) return 'HDFC';
    if (lowerFileName.contains('icici')) return 'ICICI';
    if (lowerFileName.contains('axis')) return 'Axis';
    if (lowerFileName.contains('kotak')) return 'Kotak';

    // Search header strings
    for (final row in rows.take(5)) {
      final rowStr = row.join(' ').toLowerCase();
      if (rowStr.contains('state bank') || rowStr.contains('sbi')) return 'SBI';
      if (rowStr.contains('hdfc')) return 'HDFC';
      if (rowStr.contains('icici')) return 'ICICI';
      if (rowStr.contains('axis')) return 'Axis';
      if (rowStr.contains('kotak')) return 'Kotak';
    }

    return 'Unknown';
  }

  /// Locate the index containing transaction column headers
  static int _findHeaderRowIndex(List<List<dynamic>> rows) {
    final headerKeywords = ['date', 'txn date', 'transaction date', 'description', 'particulars', 'amount', 'withdrawal', 'deposit'];
    for (int i = 0; i < rows.length; i++) {
      final matches = rows[i].where((col) {
        final val = col.toString().toLowerCase();
        return headerKeywords.any((kw) => val.contains(kw));
      });
      if (matches.length >= 2) {
        return i;
      }
    }
    return -1;
  }

  /// Build column mapping configuration dynamically
  static _ColumnMapping _getColumnMapping(List<dynamic> headerRow) {
    int dateIdx = -1;
    int descIdx = -1;
    int amountIdx = -1;
    int creditIdx = -1;
    int debitIdx = -1;
    int balanceIdx = -1;

    for (int i = 0; i < headerRow.length; i++) {
      final val = headerRow[i].toString().toLowerCase().trim();
      if (val.contains('date') || val.contains('dt')) {
        dateIdx = i;
      } else if (val.contains('desc') || val.contains('particulars') || val.contains('narration')) {
        descIdx = i;
      } else if (val.contains('amount') || val.contains('amt')) {
        amountIdx = i;
      } else if (val.contains('deposit') || val.contains('credit') || val.contains('cr')) {
        creditIdx = i;
      } else if (val.contains('withdraw') || val.contains('debit') || val.contains('dr')) {
        debitIdx = i;
      } else if (val.contains('balance') || val.contains('bal')) {
        balanceIdx = i;
      }
    }

    // Default fallbacks if headers are unnamed/malformed
    if (dateIdx == -1) dateIdx = 0;
    if (descIdx == -1) descIdx = 1;
    if (amountIdx == -1 && creditIdx == -1) amountIdx = 2;

    return _ColumnMapping(
      dateIndex: dateIdx,
      descriptionIndex: descIdx,
      amountIndex: amountIdx,
      creditIndex: creditIdx,
      debitIndex: debitIdx,
      balanceIndex: balanceIdx,
      minRequiredColumns: [dateIdx, descIdx, amountIdx, creditIdx, debitIdx].where((idx) => idx != -1).reduce((a, b) => a > b ? a : b) + 1,
    );
  }

  /// Parse an individual row safely
  static ParsedTransaction? _parseRow(
    List<dynamic> row,
    int index,
    _ColumnMapping mapping,
    String bank,
    String fileName,
  ) {
    try {
      final dateStr = row[mapping.dateIndex].toString().trim();
      final desc = row[mapping.descriptionIndex].toString().trim();
      
      if (dateStr.isEmpty || dateStr.contains('#') || desc.isEmpty) {
        return null;
      }

      final date = _parseDate(dateStr);
      if (date == null) return null;

      double amount = 0.0;
      bool isCredit = true;

      // Extract amount depending on split credit/debit columns or a single amount column
      if (mapping.creditIndex != -1 && mapping.debitIndex != -1) {
        final creditStr = row[mapping.creditIndex].toString().trim();
        final debitStr = row[mapping.debitIndex].toString().trim();

        if (creditStr.isNotEmpty && _parseAmount(creditStr) > 0) {
          amount = _parseAmount(creditStr);
          isCredit = true;
        } else if (debitStr.isNotEmpty && _parseAmount(debitStr) > 0) {
          amount = _parseAmount(debitStr);
          isCredit = false;
        } else {
          return null; // No transaction value
        }
      } else {
        final amountStr = row[mapping.amountIndex].toString().trim();
        amount = _parseAmount(amountStr);
        if (amount == 0.0) return null;

        // Auto classify credit vs debit based on amount prefix or description text
        if (amountStr.startsWith('-') || amountStr.contains('DR') || desc.toLowerCase().contains('debit') || desc.toLowerCase().contains('dr.')) {
          isCredit = false;
        }
        amount = amount.abs();
      }

      // Normalization & classification
      final normalizedSource = _normalizeSource(desc);
      final classification = _classifyTransaction(desc, amount, normalizedSource, isCredit);

      return ParsedTransaction(
        amount: amount,
        sender: bank,
        platform: 'Bank Statement',
        date: date,
        reference: 'BS_REF_${index}_${date.millisecondsSinceEpoch}',
        bank: bank,
        rawMessage: row.join(' | '),
        isCredit: isCredit,
        confidence: 0.9,
        classification: classification,
        source: normalizedSource,
      );
    } catch (e) {
      return null;
    }
  }

  static double _parseAmount(String amountStr) {
    try {
      String cleaned = amountStr
          .replaceAll('₹', '')
          .replaceAll('Rs', '')
          .replaceAll('Rs.', '')
          .replaceAll(',', '')
          .replaceAll(' ', '')
          .trim();
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static DateTime? _parseDate(String dateStr) {
    final formats = [
      'd/M/yyyy', 'dd/MM/yyyy', 'd-M-yyyy', 'dd-MM-yyyy',
      'yyyy/MM/dd', 'yyyy-MM-dd', 'dd MMM yyyy', 'MMM dd, yyyy'
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

  static String _normalizeSource(String desc) {
    final lower = desc.toLowerCase();
    final mappings = {
      'Swiggy': ['swiggy', 'swigy', 'instamart'],
      'Zomato': ['zomato', 'blinkit'],
      'Uber': ['uber'],
      'Ola': ['ola'],
      'Zepto': ['zepto'],
      'Salary': ['salary', 'payroll', 'stipend'],
    };

    for (final entry in mappings.entries) {
      for (final variant in entry.value) {
        if (lower.contains(variant)) {
          return entry.key;
        }
      }
    }
    return 'Other Payer';
  }

  static String _classifyTransaction(String desc, double amount, String source, bool isCredit) {
    if (!isCredit) return 'Other';
    if (source == 'Salary') return 'Salary';
    
    final gigSources = ['swiggy', 'zomato', 'uber', 'ola', 'zepto'];
    if (gigSources.contains(source.toLowerCase())) {
      return 'Gig Income';
    }

    final lowerDesc = desc.toLowerCase();
    if (lowerDesc.contains('freelance') || lowerDesc.contains('upwork') || lowerDesc.contains('fiverr')) {
      return 'Freelance Income';
    }

    return 'Other';
  }
}

class _ColumnMapping {
  final int dateIndex;
  final int descriptionIndex;
  final int amountIndex;
  final int creditIndex;
  final int debitIndex;
  final int balanceIndex;
  final int minRequiredColumns;

  _ColumnMapping({
    required this.dateIndex,
    required this.descriptionIndex,
    required this.amountIndex,
    required this.creditIndex,
    required this.debitIndex,
    required this.balanceIndex,
    required this.minRequiredColumns,
  });
}
