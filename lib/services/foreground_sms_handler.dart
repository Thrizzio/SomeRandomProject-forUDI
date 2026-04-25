import 'package:flutter/material.dart';
import 'background_sms_service.dart';

/// Manager for background SMS service lifecycle and UI interactions
class ForegroundSmsHandler {
  static final ForegroundSmsHandler _instance = ForegroundSmsHandler._internal();

  factory ForegroundSmsHandler() {
    return _instance;
  }

  ForegroundSmsHandler._internal();

  final BackgroundSmsService _smsService = BackgroundSmsService();
  bool _initialized = false;

  /// Initialize the foreground SMS handler
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('✅ Foreground SMS Handler already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing Foreground SMS Handler...');
      await _smsService.initialize();
      _initialized = true;
      debugPrint('✅ Foreground SMS Handler initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Foreground SMS Handler: $e');
    }
  }

  /// Enable SMS background listening
  Future<bool> enableBackgroundSmsListener() async {
    try {
      await _smsService.startListening();
      debugPrint('✅ Background SMS listener enabled');
      return true;
    } catch (e) {
      debugPrint('❌ Error enabling background SMS listener: $e');
      return false;
    }
  }

  /// Disable SMS background listening
  Future<bool> disableBackgroundSmsListener() async {
    try {
      await _smsService.stopListening();
      debugPrint('✅ Background SMS listener disabled');
      return true;
    } catch (e) {
      debugPrint('❌ Error disabling background SMS listener: $e');
      return false;
    }
  }

  /// Check if SMS listener is active
  Future<bool> isListenerActive() async {
    return await _smsService.isListenerActive();
  }

  /// Get SMS service statistics
  Future<Map<String, dynamic>> getServiceStats() async {
    return await _smsService.getStatistics();
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      await _smsService.dispose();
      _initialized = false;
      debugPrint('✅ Foreground SMS Handler disposed');
    } catch (e) {
      debugPrint('❌ Error disposing Foreground SMS Handler: $e');
    }
  }
}
