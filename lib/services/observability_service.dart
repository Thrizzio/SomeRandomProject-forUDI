import 'app_logger.dart';

class ObservabilityService {
  static const String _tag = 'ObservabilityService';

  // Metrics state
  static int _totalSmsParsed = 0;
  static int _failedSmsParses = 0;
  static int _duplicateSmsDetected = 0;

  static int _totalCsvRowsProcessed = 0;
  static int _failedCsvRows = 0;
  static int _duplicateCsvRows = 0;

  /// Track a successful SMS parse
  static void trackSmsSuccess() {
    _totalSmsParsed++;
    _logMetrics();
  }

  /// Track a failed SMS parse
  static void trackSmsFailure(String reason) {
    _failedSmsParses++;
    AppLogger.warning(_tag, 'SMS parsing failed: $reason');
    _logMetrics();
  }

  /// Track a duplicate SMS detection
  static void trackSmsDuplicate() {
    _duplicateSmsDetected++;
    _logMetrics();
  }

  /// Track CSV row metrics
  static void trackCsvRow(bool isSuccess, bool isDuplicate) {
    _totalCsvRowsProcessed++;
    if (isDuplicate) {
      _duplicateCsvRows++;
    } else if (!isSuccess) {
      _failedCsvRows++;
    }
  }

  /// Retrieve full metrics report
  static Map<String, dynamic> getMetricsReport() {
    final double smsAccuracy = _totalSmsParsed + _failedSmsParses == 0
        ? 1.0
        : _totalSmsParsed / (_totalSmsParsed + _failedSmsParses);

    final double smsDuplicateRate = _totalSmsParsed == 0
        ? 0.0
        : _duplicateSmsDetected / _totalSmsParsed;

    final double csvSuccessRate = _totalCsvRowsProcessed == 0
        ? 1.0
        : (_totalCsvRowsProcessed - _failedCsvRows) / _totalCsvRowsProcessed;

    return {
      'sms': {
        'totalParsed': _totalSmsParsed,
        'failedParses': _failedSmsParses,
        'duplicatesDetected': _duplicateSmsDetected,
        'accuracy': smsAccuracy,
        'duplicateRate': smsDuplicateRate,
      },
      'csv': {
        'totalRowsProcessed': _totalCsvRowsProcessed,
        'failedRows': _failedCsvRows,
        'duplicateRows': _duplicateCsvRows,
        'successRate': csvSuccessRate,
      }
    };
  }

  static void _logMetrics() {
    final report = getMetricsReport();
    AppLogger.info(
      _tag,
      'Metrics Update: SMS Accuracy: ${(report['sms']['accuracy'] * 100).toStringAsFixed(1)}%, '
      'Duplicate Rate: ${(report['sms']['duplicateRate'] * 100).toStringAsFixed(1)}%, '
      'CSV Success Rate: ${(report['csv']['successRate'] * 100).toStringAsFixed(1)}%',
    );
  }
}
