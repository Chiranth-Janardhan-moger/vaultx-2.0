import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/theme/app_theme.dart';

/// Tactile vibration patterns and delightful visual notifications for celebratory,
/// successful, and affirmative user interactions ("Happy Feedback").
class HappyFeedback {
  HappyFeedback._();

  /// Plays the signature "Happy Vibration" pattern:
  /// A quick, energetic double-pulse cadence (light tap followed 75ms later by a crisp medium impact),
  /// evoking delight and tactile confirmation of success (similar to iOS UINotificationFeedbackGenerator .success).
  static Future<void> vibrate() async {
    try {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 75));
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Gracefully ignore on platforms/headless environments without haptics
    }
  }

  /// Plays an extra celebratory, grand vibration cadence for milestone accomplishments
  /// (e.g. master password setup/change, device sync pairing completion, or biometric enrollment).
  static Future<void> celebrate() async {
    try {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Gracefully ignore
    }
  }

  /// Displays a floating Material 3 Expressive happy snackbar with an emerald glow,
  /// affirmative icon, and concurrently triggers the happy vibration.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    IconData icon = Icons.check_circle_rounded,
    Duration duration = const Duration(milliseconds: 2200),
    bool playVibration = true,
  }) {
    if (playVibration) {
      unawaited(vibrate());
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: EdgeInsets.zero,
        content: _HappyFeedbackBanner(
          message: message,
          title: title,
          icon: icon,
        ),
      ),
    );
  }
}

class _HappyFeedbackBanner extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;

  const _HappyFeedbackBanner({
    required this.message,
    this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131E18) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.emerald500.withAlpha(isDark ? 160 : 200),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald500.withAlpha(isDark ? 55 : 35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.emerald500.withAlpha(isDark ? 45 : 25),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.emerald500.withAlpha(isDark ? 90 : 120),
                width: 1,
              ),
            ),
            child: Icon(icon, color: AppColors.emerald500, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontSize: title != null ? 12 : 13,
                    fontWeight: title != null ? FontWeight.w500 : FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
