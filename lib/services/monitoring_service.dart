import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

class MonitoringService {
  static const String _tag = 'MonitoringService';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track app start
  static DateTime? _appStartTime;
  static double appStartDurationSeconds = 0.0;

  static void recordAppStart() {
    _appStartTime = DateTime.now();
    AppLogger.info(_tag, 'App start recorded: $_appStartTime');
  }

  static void recordAppReady() {
    if (_appStartTime != null) {
      final now = DateTime.now();
      appStartDurationSeconds = now.difference(_appStartTime!).inMilliseconds / 1000.0;
      AppLogger.info(_tag, 'App fully loaded in ${appStartDurationSeconds}s');
      _logPerformanceMetric('app_start', appStartDurationSeconds);
    }
  }

  // Crashlytics tracking
  static Future<void> logFatalCrash(dynamic error, StackTrace stack) async {
    AppLogger.error(_tag, 'FATAL CRASH DETECTED', error, stack);
    await _sendDiagnosticToFirestore(
      type: 'fatal_crash',
      message: error.toString(),
      details: stack.toString(),
    );
  }

  static Future<void> logNonFatalError(dynamic error, {String context = ''}) async {
    AppLogger.warning(_tag, 'Non-Fatal Error [$context]: $error');
    await _sendDiagnosticToFirestore(
      type: 'non_fatal_error',
      message: error.toString(),
      details: 'Context: $context',
    );
  }

  static Future<void> logParserFailure(String messageBody, String errorDetails) async {
    AppLogger.error(_tag, 'Parser Failure on message: "$messageBody"', errorDetails);
    await _sendDiagnosticToFirestore(
      type: 'parser_failure',
      message: 'Failed parsing message: "${messageBody.length > 50 ? messageBody.substring(0, 50) + "..." : messageBody}"',
      details: errorDetails,
    );
  }

  static Future<void> logReportFailure(String reportType, String errorDetails) async {
    AppLogger.error(_tag, 'PDF Report Generation Failure: $reportType', errorDetails);
    await _sendDiagnosticToFirestore(
      type: 'report_failure',
      message: 'PDF generation failed for report: $reportType',
      details: errorDetails,
    );
  }

  // Performance monitoring
  static Future<void> logDashboardLoadTime(double durationSeconds) async {
    AppLogger.info(_tag, 'Dashboard loaded in ${durationSeconds}s');
    await _logPerformanceMetric('dashboard_load_time', durationSeconds);
  }

  static Future<void> logParserLatency(double durationMs) async {
    AppLogger.info(_tag, 'SMS Parser execution took ${durationMs}ms');
    await _logPerformanceMetric('parser_latency_ms', durationMs);
  }

  static Future<void> logDbQueryDuration(String queryName, double durationMs) async {
    AppLogger.info(_tag, 'DB Query "$queryName" executed in ${durationMs}ms');
    await _logPerformanceMetric('db_query_duration_${queryName}', durationMs);
  }

  // Helper calls
  static Future<void> _sendDiagnosticToFirestore({
    required String type,
    required String message,
    required String details,
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'guest';
      final userEmail = user?.email ?? 'anonymous';

      await _firestore.collection('diagnostics_and_crashes').add({
        'type': type,
        'message': message,
        'details': details,
        'userId': userId,
        'userEmail': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': 'Web/Android Hybrid Platform',
      });
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to log diagnostic to Firestore: $e');
    }
  }

  static Future<void> _logPerformanceMetric(String metricName, double value) async {
    try {
      await _firestore.collection('performance_metrics').add({
        'metricName': metricName,
        'value': value,
        'userId': _auth.currentUser?.uid ?? 'guest',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Avoid recursive loops or logging issues
    }
  }

  // Retrieve issues for Admin dashboard
  static Stream<QuerySnapshot> getDiagnosticsStream() {
    return _firestore
        .collection('diagnostics_and_crashes')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
