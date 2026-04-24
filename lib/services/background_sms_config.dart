/// Configuration for Background SMS Service
class BackgroundSmsConfig {
  /// Enable/disable background SMS listening
  final bool enableBackgroundListener;

  /// Check interval for background SMS processing (in minutes)
  final int checkIntervalMinutes;

  /// Enable debug logging
  final bool debugLogging;

  /// Maximum retry attempts for failed SMS parsing
  final int maxRetryAttempts;

  /// Retry delay in seconds
  final int retryDelaySeconds;

  /// Auto-initialize on app start
  final bool autoInitialize;

  /// Supported gig platforms for parsing
  final List<String> supportedPlatforms;

  const BackgroundSmsConfig({
    this.enableBackgroundListener = true,
    this.checkIntervalMinutes = 15,
    this.debugLogging = true,
    this.maxRetryAttempts = 3,
    this.retryDelaySeconds = 30,
    this.autoInitialize = true,
    this.supportedPlatforms = const [
      'Swiggy',
      'Zomato',
      'Uber',
      'Ola',
      'Zepto',
    ],
  });

  @override
  String toString() => 'BackgroundSmsConfig('
      'enableBackgroundListener: $enableBackgroundListener, '
      'checkInterval: ${checkIntervalMinutes}m, '
      'debugLogging: $debugLogging, '
      'maxRetries: $maxRetryAttempts, '
      'retryDelay: ${retryDelaySeconds}s, '
      'autoInit: $autoInitialize, '
      'platforms: ${supportedPlatforms.join(", ")})';
}

/// Default configuration for background SMS service
const BackgroundSmsConfig defaultBackgroundSmsConfig = BackgroundSmsConfig();
