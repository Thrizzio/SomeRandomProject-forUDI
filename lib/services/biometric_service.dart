import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/app_logger.dart';

class BiometricService {
  static const String _tag = 'BiometricService';
  static final LocalAuthentication _auth = LocalAuthentication();

  // Mock overrides for unit/widget tests
  static bool? mockIsAvailable;
  static bool? mockAuthResult;

  /// Checks if the device has biometric hardware and supports checking it.
  static Future<bool> isBiometricsAvailable() async {
    if (mockIsAvailable != null) return mockIsAvailable!;
    if (kIsWeb) return false;
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to check biometric availability', e, stack);
      return false;
    }
  }

  /// Triggers the native biometric (fingerprint/face) or passcode prompt.
  static Future<bool> authenticate() async {
    if (mockAuthResult != null) return mockAuthResult!;
    if (kIsWeb) return true; // Web fallback
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to access your secure financial ledger',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allows PIN/passcode fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      AppLogger.info(_tag, 'Authentication result: $didAuthenticate');
      return didAuthenticate;
    } on PlatformException catch (e, stack) {
      AppLogger.error(_tag, 'Platform exception during authentication', e, stack);
      return false;
    } catch (e, stack) {
      AppLogger.error(_tag, 'Unexpected error during authentication', e, stack);
      return false;
    }
  }
}
