import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/crypto/totp_service.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';

/// Real-time RFC 6238 TOTP authenticator token card.
///
/// Features:
/// - Dynamic 6-digit code formatted with center space (e.g. "492 813").
/// - Countdown timer and color-shifting circular progress indicator.
/// - 1-tap quick clipboard copy with tactile haptics.
class TotpCodeWidget extends StatefulWidget {
  final String secret;
  final String? accountLabel;

  const TotpCodeWidget({
    super.key,
    required this.secret,
    this.accountLabel,
  });

  @override
  State<TotpCodeWidget> createState() => _TotpCodeWidgetState();
}

class _TotpCodeWidgetState extends State<TotpCodeWidget> {
  Timer? _ticker;
  late String _currentCode;
  late int _remainingSeconds;
  late double _progressFraction;

  @override
  void initState() {
    super.initState();
    _updateState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateState();
      }
    });
  }

  void _updateState() {
    setState(() {
      _currentCode = TotpService.generateCode(widget.secret);
      _remainingSeconds = TotpService.getRemainingSeconds();
      _progressFraction = TotpService.getProgressFraction();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Color _getStatusColor() {
    if (_remainingSeconds <= 5) return AppColors.rose500;
    if (_remainingSeconds <= 10) return AppColors.amber500;
    return AppColors.emerald500;
  }

  void _copyToClipboard() {
    HapticFeedback.lightImpact();
    ClipboardSecurityService.copySecure(
      context: context,
      ref: null,
      text: _currentCode.replaceAll(' ', ''),
      label: '2FA Code',
      isSensitive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppColors.primaryBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2FA AUTHENTICATOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      if (widget.accountLabel != null && widget.accountLabel!.isNotEmpty)
                        Text(
                          widget.accountLabel!,
                          style: TextStyle(fontSize: 12, color: mutedCol, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ],
              ),
              // Circular progress countdown
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progressFraction,
                      strokeWidth: 3,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                    Text(
                      '$_remainingSeconds',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TotpService.formatCode(_currentCode),
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                ),
              ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue.withAlpha(isDark ? 40 : 25),
                  foregroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy 2FA Code',
                onPressed: _copyToClipboard,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
