/// Production-ready logging and error handling service
enum LogLevel { debug, info, warning, error, critical }

class AppLogger {
  static const bool _enableLogging = true; // Set to false in production if needed
  static const LogLevel _minLogLevel = LogLevel.debug;

  /// Log a debug message
  static void debug(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Log an info message
  static void info(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Log a warning message
  static void warning(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  /// Log an error message
  static void error(String tag, String message, [dynamic exception, StackTrace? stackTrace]) {
    _log(LogLevel.error, tag, message);
    if (exception != null) {
      _logException(exception, stackTrace);
    }
  }

  /// Log a critical error
  static void critical(String tag, String message, [dynamic exception, StackTrace? stackTrace]) {
    _log(LogLevel.critical, tag, message);
    if (exception != null) {
      _logException(exception, stackTrace);
    }
  }

  /// Internal logging method
  static void _log(LogLevel level, String tag, String message) {
    if (!_enableLogging || level.index < _minLogLevel.index) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelName = level.toString().split('.').last.toUpperCase();
    final logMessage = '[$timestamp] [$levelName] [$tag] $message';

    // Print to console
    print(logMessage);
  }

  /// Log exception details
  static void _logException(dynamic exception, StackTrace? stackTrace) {
    print('Exception: $exception');
    if (stackTrace != null) {
      print('StackTrace:\n$stackTrace');
    }
  }
}

/// Exception handler for common app errors
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  AppException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Business logic exception
class BusinessException extends AppException {
  BusinessException({
    required String message,
    String? code,
  }) : super(message: message, code: code);
}

/// Network exception
class NetworkException extends AppException {
  NetworkException({
    required String message,
    String? code,
  }) : super(message: message, code: code ?? 'NETWORK_ERROR');
}

/// Authentication exception
class AuthException extends AppException {
  AuthException({
    required String message,
    String? code,
  }) : super(message: message, code: code ?? 'AUTH_ERROR');
}

/// Database exception
class DatabaseException extends AppException {
  DatabaseException({
    required String message,
    String? code,
  }) : super(message: message, code: code ?? 'DATABASE_ERROR');
}

/// Generic exception handler that provides user-friendly messages
String getUserFriendlyErrorMessage(dynamic error) {
  if (error is AppException) {
    return error.message;
  }

  if (error is AuthException) {
    return error.message;
  }

  if (error is NetworkException) {
    return 'Network error. Please check your connection.';
  }

  if (error is DatabaseException) {
    return 'Database error. Please try again.';
  }

  return 'An unexpected error occurred. Please try again.';
}
