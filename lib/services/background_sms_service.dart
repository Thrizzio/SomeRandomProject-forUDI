import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../read_sms.dart';
import '../models/transaction.dart' as app_models;
import 'database_service.dart';
import 'app_logger.dart';

/// Background SMS parsing service
/// Handles SMS listening in both foreground and background modes
class BackgroundSmsService {
  static final BackgroundSmsService _instance = BackgroundSmsService._internal();
  static const String _tag = 'BackgroundSmsService';

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
      AppLogger.info(_tag, 'Already initialized');
      return;
    }

    try {
      AppLogger.info(_tag, 'Initializing...');

      // Check permissions
      final hasPermission = await telephony.requestPhoneAndSmsPermissions ?? false;
      if (!hasPermission) {
        AppLogger.warning(_tag, 'SMS permission denied');
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
      AppLogger.info(_tag, 'Initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Initialization failed', e, stackTrace);
    }
  }

  /// Start listening to incoming SMS messages
  Future<void> startListening() async {
    if (_isListening) {
      AppLogger.warning(_tag, 'Already listening');
      return;
    }

    try {
      AppLogger.info(_tag, 'Starting listener...');

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

      AppLogger.info(_tag, 'Listener started successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to start listener', e, stackTrace);
      _isListening = false;
    }
  }

  /// Stop listening to SMS messages
  Future<void> stopListening() async {
    if (!_isListening) {
      AppLogger.warning(_tag, 'Not listening');
      return;
    }

    try {
      AppLogger.info(_tag, 'Stopping listener...');
      await _smsSubscription?.cancel();
      _smsSubscription = null;
      _isListening = false;

      // Save listener state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_listenerActiveKey, false);

      AppLogger.info(_tag, 'Listener stopped');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to stop listener', e, stackTrace);
    }
  }

  /// Handle incoming SMS message
  Future<void> _handleIncomingSms(SmsMessage message) async {
    try {
      AppLogger.debug(_tag, 'Received SMS from: ${message.address}');

      // Parse the SMS using existing parser
      final parsedIncome = SmsParser.parse(message);

      if (parsedIncome == null) {
        AppLogger.debug(_tag, 'SMS not a gig income message');
        return;
      }

      AppLogger.info(_tag,
          'Parsed gig income: ₹${parsedIncome.amount} from ${parsedIncome.source}');

      // Store in database
      await _storeTransaction(parsedIncome);

      AppLogger.debug(_tag, 'Transaction stored successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to handle incoming SMS', e, stackTrace);
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
        date: parsedIncome.date.toIso8601String(),
      );

      await DatabaseService.insertTransaction(transaction);
      AppLogger.debug(_tag, 'Transaction inserted into database');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to store transaction', e, stackTrace);
      rethrow;
    }
  }

  /// Get SMS listener status
  Future<bool> isListenerActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_listenerActiveKey) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to get listener status', e, stackTrace);
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
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to get statistics', e, stackTrace);
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
      AppLogger.info(_tag, 'Disposed successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Dispose failed', e, stackTrace);
    }
  }
}

/// Global callback function for background SMS processing
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == 'background_sms_parser') {
        AppLogger.info('BackgroundTask', 'Background SMS parser task running');

        final smsService = BackgroundSmsService();
        final isActive = await smsService.isListenerActive();

        if (!isActive) {
          AppLogger.info('BackgroundTask', 'Re-initializing listener');
          await smsService.initialize();
        }

        // Update last check time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'sms_last_check',
          DateTime.now().toIso8601String(),
        );

        AppLogger.info('BackgroundTask', 'Background task completed');
        return true;
      }
    } catch (e) {
      AppLogger.error('BackgroundTask', 'Background task error', e);
      return false;
    }
    return false;
  });
}
