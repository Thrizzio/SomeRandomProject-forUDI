import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../read_sms.dart';
import '../models/transaction.dart' as app_models;
import 'database_service.dart';

/// Background SMS parsing service
/// Handles SMS listening in both foreground and background modes
class BackgroundSmsService {
  static final BackgroundSmsService _instance = BackgroundSmsService._internal();

  factory BackgroundSmsService() {
    return _instance;
  }

  BackgroundSmsService._internal();

  final Telephony telephony = Telephony.instance;
  StreamSubscription<SmsMessage>? _smsSubscription;
  bool _isInitialized = false;
  bool _isListening = false;

  // Constants
  static const String _taskName = 'background_sms_parser';
  static const String _listenerActiveKey = 'sms_listener_active';
  static const Duration _checkInterval = Duration(minutes: 15);

  /// Initialize the background SMS service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('✅ Background SMS Service already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing Background SMS Service...');

      // Check permissions
      final hasPermission = await telephony.requestPhoneAndSmsPermissions ?? false;
      if (!hasPermission) {
        debugPrint('❌ SMS Permission denied');
        return;
      }

      // Initialize work manager for periodic background tasks
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Schedule periodic background SMS check
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: _checkInterval,
        constraints: Constraints(
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresNetwork: false,
        ),
      );

      // Start foreground listener
      await startListening();

      _isInitialized = true;
      debugPrint('✅ Background SMS Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Background SMS Service: $e');
    }
  }

  /// Start listening to incoming SMS messages
  Future<void> startListening() async {
    if (_isListening) {
      debugPrint('⚠️ SMS Listener already active');
      return;
    }

    try {
      debugPrint('📱 Starting SMS listener...');

      // Listen to incoming SMS messages in foreground
      _smsSubscription = telephony.onSmsReceived?.listen((SmsMessage message) {
        _handleIncomingSms(message);
      });

      // Also listen to SMS from the background
      await telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          _handleIncomingSms(message);
        },
        listenInBackground: true,
      );

      _isListening = true;

      // Save listener state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_listenerActiveKey, true);

      debugPrint('✅ SMS Listener started successfully');
    } catch (e) {
      debugPrint('❌ Error starting SMS listener: $e');
      _isListening = false;
    }
  }

  /// Stop listening to SMS messages
  Future<void> stopListening() async {
    if (!_isListening) {
      debugPrint('⚠️ SMS Listener not active');
      return;
    }

    try {
      debugPrint('📵 Stopping SMS listener...');
      await _smsSubscription?.cancel();
      _smsSubscription = null;
      _isListening = false;

      // Save listener state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_listenerActiveKey, false);

      debugPrint('✅ SMS Listener stopped');
    } catch (e) {
      debugPrint('❌ Error stopping SMS listener: $e');
    }
  }

  /// Handle incoming SMS message
  Future<void> _handleIncomingSms(SmsMessage message) async {
    try {
      debugPrint('📨 Received SMS from: ${message.address}');

      // Parse the SMS using existing parser
      final parsedIncome = SmsParser.parse(message);

      if (parsedIncome == null) {
        debugPrint('⏭️ SMS not a gig income message, skipping');
        return;
      }

      debugPrint('✅ Parsed valid gig income: ₹${parsedIncome.amount} from ${parsedIncome.source}');

      // Store in database
      await _storeTransaction(parsedIncome);

      debugPrint('💾 Transaction stored successfully');
    } catch (e) {
      debugPrint('❌ Error handling incoming SMS: $e');
    }
  }

  /// Store parsed transaction in database
  Future<void> _storeTransaction(ParsedIncome parsedIncome) async {
    try {
      final transaction = app_models.Transaction(
        amount: parsedIncome.amount.toString(),
        sender: parsedIncome.source,
        messageBody: 'Gig income from ${parsedIncome.source}',
        transactionType: 'income',
        date: parsedIncome.date,
      );

      await DatabaseService.insertTransaction(transaction);
      debugPrint('✅ Transaction inserted into database');
    } catch (e) {
      debugPrint('❌ Error storing transaction: $e');
      rethrow;
    }
  }

  /// Get SMS listener status
  Future<bool> isListenerActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_listenerActiveKey) ?? false;
    } catch (e) {
      debugPrint('❌ Error getting listener status: $e');
      return _isListening;
    }
  }

  /// Get SMS listening statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'isInitialized': _isInitialized,
        'isListening': _isListening,
        'lastCheck': prefs.getString('sms_last_check'),
        'totalProcessed': prefs.getInt('sms_total_processed') ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Error getting statistics: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      await stopListening();
      await Workmanager().cancelAll();
      _isInitialized = false;
      debugPrint('✅ Background SMS Service disposed');
    } catch (e) {
      debugPrint('❌ Error disposing Background SMS Service: $e');
    }
  }
}

/// Global callback function for background SMS processing
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == 'background_sms_parser') {
        debugPrint('🔄 Background SMS Parser task running...');

        final smsService = BackgroundSmsService();
        final isActive = await smsService.isListenerActive();

        if (!isActive) {
          debugPrint('📵 Listener not active, re-initializing...');
          await smsService.initialize();
        }

        // Update last check time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'sms_last_check',
          DateTime.now().toIso8601String(),
        );

        debugPrint('✅ Background task completed');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Background task error: $e');
      return false;
    }
    return false;
  });
}
