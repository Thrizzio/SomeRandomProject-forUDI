import '../models/parsed_transaction.dart';
import 'app_logger.dart';

class DataCleaningService {
  static const String _tag = 'DataCleaningService';

  /// Validate a transaction and check for duplicates before writing to store
  static CleaningResult cleanAndValidate(
    ParsedTransaction transaction,
    List<ParsedTransaction> existingTransactions, {
    Duration timeWindow = const Duration(minutes: 5),
  }) {
    try {
      // 1. Structural/Value Validations
      if (transaction.amount <= 0) {
        return CleaningResult.invalid('Amount must be positive: ${transaction.amount}');
      }

      if (transaction.date.isAfter(DateTime.now().add(const Duration(minutes: 10)))) {
        return CleaningResult.invalid('Transaction date is in the future: ${transaction.date}');
      }

      if (transaction.source.isEmpty || transaction.source == 'Unknown') {
        return CleaningResult.invalid('Invalid or empty source specified.');
      }

      // Check for character corruptions (e.g. garbled symbols)
      if (transaction.rawMessage.contains('') || transaction.rawMessage.contains('???')) {
        return CleaningResult.invalid('Raw message contains corrupt characters.');
      }

      // 2. Duplicate Detection logic
      double duplicateScore = 0.0;
      String matchedRef = '';

      for (final existing in existingTransactions) {
        // Rule A: Same reference ID (strongest match)
        if (transaction.reference.isNotEmpty &&
            existing.reference.isNotEmpty &&
            transaction.reference == existing.reference) {
          duplicateScore = 1.0;
          matchedRef = existing.reference;
          break;
        }

        // Rule B: Same amount, same source, and within a narrow time window
        final timeDiff = transaction.date.difference(existing.date).abs();
        if (transaction.amount == existing.amount &&
            transaction.source == existing.source &&
            timeDiff <= timeWindow) {
          duplicateScore = 0.9;
          matchedRef = existing.reference;
          break;
        }

        // Rule C: Same amount and reference (even if time window is slightly off)
        if (transaction.amount == existing.amount &&
            transaction.reference.isNotEmpty &&
            transaction.reference == existing.reference) {
          duplicateScore = 1.0;
          matchedRef = existing.reference;
          break;
        }
      }

      if (duplicateScore >= 0.8) {
        AppLogger.warning(
          _tag,
          'Duplicate transaction detected (Score: $duplicateScore). Ref: ${transaction.reference}, Matching: $matchedRef',
        );
        return CleaningResult.duplicate(duplicateScore, matchedRef);
      }

      // Cleaned successfully
      return CleaningResult.valid(transaction);
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Validation check failed', e, stackTrace);
      return CleaningResult.invalid('Validation error: $e');
    }
  }
}

class CleaningResult {
  final bool isValid;
  final bool isDuplicate;
  final double duplicateConfidence;
  final String duplicateRef;
  final String errorMessage;
  final ParsedTransaction? cleanedTransaction;

  CleaningResult._({
    required this.isValid,
    required this.isDuplicate,
    this.duplicateConfidence = 0.0,
    this.duplicateRef = '',
    this.errorMessage = '',
    this.cleanedTransaction,
  });

  factory CleaningResult.valid(ParsedTransaction tx) {
    return CleaningResult._(
      isValid: true,
      isDuplicate: false,
      cleanedTransaction: tx,
    );
  }

  factory CleaningResult.invalid(String message) {
    return CleaningResult._(
      isValid: false,
      isDuplicate: false,
      errorMessage: message,
    );
  }

  factory CleaningResult.duplicate(double confidence, String matchRef) {
    return CleaningResult._(
      isValid: true,
      isDuplicate: true,
      duplicateConfidence: confidence,
      duplicateRef: matchRef,
    );
  }
}
