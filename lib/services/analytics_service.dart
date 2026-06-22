import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

class AnalyticsService {
  static const String _tag = 'AnalyticsService';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logEvent({
    required String eventName,
    required String category,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'guest';
      final email = user?.email ?? 'anonymous';

      await _firestore.collection('product_analytics').add({
        'eventName': eventName,
        'category': category,
        'userId': userId,
        'userEmail': email,
        'timestamp': FieldValue.serverTimestamp(),
        'parameters': parameters ?? {},
      });

      // Also update user's last active date for cohort/retention tracking
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'email': email,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to log event $eventName: $e');
    }
  }

  // Specific helpers
  static Future<void> logSignup(String email) async {
    await logEvent(
      eventName: 'user_signup',
      category: 'onboarding',
      parameters: {'email': email},
    );
  }

  static Future<void> logOnboardingComplete() async {
    await logEvent(
      eventName: 'onboarding_complete',
      category: 'onboarding',
    );
  }

  static Future<void> logActiveSession() async {
    await logEvent(
      eventName: 'active_session',
      category: 'retention',
    );
  }

  static Future<void> logIncomeImport(String source, int count, double total) async {
    await logEvent(
      eventName: 'income_imported',
      category: 'import',
      parameters: {
        'source': source,
        'recordCount': count,
        'totalValue': total,
      },
    );
  }

  static Future<void> logSmsParsed(String engine, double amount) async {
    await logEvent(
      eventName: 'sms_parsed',
      category: 'parser',
      parameters: {
        'gateway': engine,
        'amount': amount,
      },
    );
  }

  static Future<void> logTaxReportGenerated(String reportType) async {
    await logEvent(
      eventName: 'tax_report_generated',
      category: 'report',
      parameters: {'reportType': reportType},
    );
  }

  static Future<void> logProUpgrade(String planName, double amount) async {
    await logEvent(
      eventName: 'pro_upgrade_success',
      category: 'monetization',
      parameters: {
        'plan': planName,
        'value': amount,
        'currency': 'INR',
      },
    );
  }

  static Future<void> logReferralGenerated(String code) async {
    await logEvent(
      eventName: 'referral_code_generated',
      category: 'growth',
      parameters: {'code': code},
    );
  }

  static Future<void> logReferralUsed(String code, String newEmail) async {
    await logEvent(
      eventName: 'referral_code_redeemed',
      category: 'growth',
      parameters: {
        'code': code,
        'referredEmail': newEmail,
      },
    );
  }

  // Retrieve analytics data stream for dashboards
  static Stream<QuerySnapshot> getAnalyticsStream() {
    return _firestore.collection('product_analytics').snapshots();
  }
}
