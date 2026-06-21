import 'dart:ui';
import 'package:flutter/material.dart';

class DesignSystem {
  // Brand Colors (Deep Slate, Electric Violet, Emerald Success, Amber Warning, Rose Error)
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color secondary = Color(0xFF8B5CF6); // Violet
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Rose
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50

  static const Color cardDark = Color(0x1F1E293B); // Semi-transparent Slate 800
  static const Color cardLight = Color(0xFFFFFFFF);

  // Gradient definitions
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient successGradient = LinearGradient(
    colors: [success, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient warningGradient = LinearGradient(
    colors: [warning, Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Spacing Tokens
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  // Premium Glassmorphism Card
  static Widget glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 20.0,
    bool isDark = true,
    Border? border,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Color(0x1F1E293B) : Color(0x9EFFFFFF),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(
              color: isDark ? Color(0x1FFFFFFF) : Color(0x1F000000),
              width: 1.5,
            ),
          ),
          padding: padding ?? const EdgeInsets.all(md),
          child: child,
        ),
      ),
    );
  }

  // Premium Gradient Button
  static Widget gradientButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else ...[
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Clean empty state display
  static Widget emptyState({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    VoidCallback? onAction,
    String? actionLabel,
    bool isDark = true,
  }) {
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final subColor = isDark ? Colors.white38 : Colors.black54;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: primary),
            ),
            const SizedBox(height: md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
            ),
            const SizedBox(height: sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: subColor,
                  ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: lg),
              gradientButton(text: actionLabel, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
