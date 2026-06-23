import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';
import '../theme/design_system.dart';

class BiometricLockWrapper extends StatefulWidget {
  final Widget child;

  const BiometricLockWrapper({super.key, required this.child});

  @override
  State<BiometricLockWrapper> createState() => _BiometricLockWrapperState();
}

class _BiometricLockWrapperState extends State<BiometricLockWrapper> {
  bool _isLoading = true;
  bool _lockEnabled = false;
  bool _isUnlocked = false;
  bool _isBiometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
    
    if (!lockEnabled) {
      if (mounted) {
        setState(() {
          _lockEnabled = false;
          _isLoading = false;
        });
      }
      return;
    }

    final available = await BiometricService.isBiometricsAvailable();
    if (!available) {
      if (mounted) {
        setState(() {
          _lockEnabled = true;
          _isBiometricsAvailable = false;
          _isLoading = false;
          _isUnlocked = true; // Bypass if hardware/system doesn't support biometrics
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _lockEnabled = true;
        _isBiometricsAvailable = true;
        _isLoading = false;
      });
    }

    // Automatically trigger biometric authentication prompt on launch
    _authenticate();
  }

  Future<void> _authenticate() async {
    final success = await BiometricService.authenticate();
    if (success && mounted) {
      setState(() {
        _isUnlocked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DesignSystem.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: DesignSystem.primary)),
      );
    }

    if (!_lockEnabled || _isUnlocked) {
      return widget.child;
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignSystem.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon Container with subtle glow/gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: DesignSystem.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: DesignSystem.primary.withValues(alpha: 0.2), width: 2),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: DesignSystem.primary,
                    size: 64,
                  ),
                ),
                const SizedBox(height: DesignSystem.lg),

                // Vault status
                Text(
                  'GigTax Vault Locked',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: DesignSystem.sm),

                // Subtitle instructions
                const Text(
                  'Biometric authentication is required to access your financial records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: DesignSystem.xl),

                // Action button
                DesignSystem.gradientButton(
                  text: 'Unlock Vault',
                  icon: Icons.fingerprint,
                  onPressed: _authenticate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
