import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';

/// Floating Glassmorphic Top Notification Pill (Dynamic Island style)
/// Slides down from the top notch with an emerald/blue specular glow,
/// live countdown progress line, and 1-tap instant clipboard wipe.
class FloatingTopPill {
  FloatingTopPill._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show({
    BuildContext? context,
    required String title,
    String? subtitle,
    IconData icon = Icons.check_circle_rounded,
    Duration duration = const Duration(seconds: 4),
    Duration? countdownDuration,
    VoidCallback? onTap,
    Color accentColor = AppColors.emerald500,
  }) {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    OverlayState? overlayState;
    if (context != null && context.mounted) {
      overlayState = Overlay.maybeOf(context, rootOverlay: true);
    }
    overlayState ??= AppGlobals.navigatorKey.currentState?.overlay;

    if (overlayState == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _FloatingTopPillWidget(
        title: title,
        subtitle: subtitle,
        icon: icon,
        accentColor: accentColor,
        countdownDuration: countdownDuration ?? duration,
        onTap: () {
          _dismiss();
          onTap?.call();
        },
        onDismiss: _dismiss,
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(countdownDuration ?? duration, () {
      _dismiss();
    });
  }

  static void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _FloatingTopPillWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final Duration countdownDuration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FloatingTopPillWidget({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.countdownDuration,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_FloatingTopPillWidget> createState() => _FloatingTopPillWidgetState();
}

class _FloatingTopPillWidgetState extends State<_FloatingTopPillWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Cubic(0.05, 0.7, 0.1, 1.0),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top > 0 ? mediaQuery.padding.top : 24.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value * 60),
              child: Opacity(
                opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _handleDismiss();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xEE12151B)
                        : Colors.white.withAlpha(240),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(30)
                          : Colors.black.withAlpha(20),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withAlpha(isDark ? 35 : 20),
                        blurRadius: 18,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 100 : 30),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Glowing Icon Monogram
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: widget.accentColor.withAlpha(isDark ? 40 : 25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.accentColor.withAlpha(120),
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: widget.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text block
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Close / Wipe Action
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Wipe',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
