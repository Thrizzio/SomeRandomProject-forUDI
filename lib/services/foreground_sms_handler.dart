import 'background_sms_service.dart';
import 'app_logger.dart';

/// Manager for background SMS service lifecycle and UI interactions
class ForegroundSmsHandler {
  static final ForegroundSmsHandler _instance = ForegroundSmsHandler._internal();
  static const String _tag = 'ForegroundSmsHandler';

  factory ForegroundSmsHandler() {
    return _instance;
  }

  ForegroundSmsHandler._internal();

  final BackgroundSmsService _smsService = BackgroundSmsService();
  bool _initialized = false;

  /// Initialize the foreground SMS handler
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.info(_tag, 'Already initialized');
      return;
    }

    try {
      AppLogger.info(_tag, 'Initializing...');
      await _smsService.initialize();
      _initialized = true;
      AppLogger.info(_tag, 'Initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Initialization failed', e, stackTrace);
    }
  }

  /// Enable SMS background listening
  Future<bool> enableBackgroundSmsListener() async {
    try {
      await _smsService.startListening();
      AppLogger.info(_tag, 'Background SMS listener enabled');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to enable background SMS listener', e, stackTrace);
      return false;
    }
  }

  /// Disable SMS background listening
  Future<bool> disableBackgroundSmsListener() async {
    try {
      await _smsService.stopListening();
      AppLogger.info(_tag, 'Background SMS listener disabled');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to disable background SMS listener', e, stackTrace);
      return false;
    }
  }

  /// Check if SMS listener is active
  Future<bool> isListenerActive() async {
    try {
      return await _smsService.isListenerActive();
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to check listener status', e, stackTrace);
      return false;
    }
  }

  /// Get SMS service statistics
  Future<Map<String, dynamic>> getServiceStats() async {
    try {
      return await _smsService.getStatistics();
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to get service statistics', e, stackTrace);
      return {};
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      await _smsService.dispose();
      _initialized = false;
      AppLogger.info(_tag, 'Disposed successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Dispose failed', e, stackTrace);
    }
  }
}
