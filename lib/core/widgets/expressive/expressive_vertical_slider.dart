import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/expressive_motion.dart';

/// Material 3 Expressive Vertical Motion Slider (tactile ruler / ladder).
/// Features dynamic track breathing, spring-animated thumb pill,
/// glowing rung markers, and a lateral floating value badge.
class ExpressiveVerticalMotionSlider extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final double? height;
  final double width;
  final String Function(int value)? labelFormatter;
  final Color? activeColor;

  const ExpressiveVerticalMotionSlider({
    super.key,
    required this.value,
    this.min = 8,
    this.max = 32,
    required this.onChanged,
    this.height,
    this.width = 68.0,
    this.labelFormatter,
    this.activeColor,
  }) : assert(max > min, 'max must be greater than min');

  @override
  State<ExpressiveVerticalMotionSlider> createState() =>
      _ExpressiveVerticalMotionSliderState();
}

class _ExpressiveVerticalMotionSliderState
    extends State<ExpressiveVerticalMotionSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _interactionController;
  late Animation<double> _thumbScaleAnimation;
  late Animation<double> _badgeScaleAnimation;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _interactionController = AnimationController(
      vsync: this,
      duration: ExpressiveMotion.durationMedium1,
      reverseDuration: ExpressiveMotion.durationMedium2,
    );

    _thumbScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(
      CurvedAnimation(
        parent: _interactionController,
        curve: ExpressiveMotion.snappy,
        reverseCurve: Curves.easeOutCubic,
      ),
    );

    _badgeScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _interactionController,
        curve: ExpressiveMotion.snappy,
        reverseCurve: Curves.easeInBack,
      ),
    );
  }

  @override
  void dispose() {
    _interactionController.dispose();
    super.dispose();
  }

  void _onInteractionStart(Offset localPos, double height) {
    setState(() => _isInteracting = true);
    _interactionController.forward();
    _updateValue(localPos.dy, height);
  }

  void _onInteractionUpdate(Offset localPos, double height) {
    _updateValue(localPos.dy, height);
  }

  void _onInteractionEnd() {
    setState(() => _isInteracting = false);
    _interactionController.reverse();
  }

  void _updateValue(double dy, double height) {
    if (height <= 0) return;
    // Invert Y: top is max, bottom is min
    final fraction = (1.0 - (dy / height)).clamp(0.0, 1.0);
    final newValue = (widget.min + (fraction * (widget.max - widget.min))).round();
    if (newValue != widget.value) {
      HapticFeedback.selectionClick();
      widget.onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.activeColor ?? AppColors.primaryBlue;

    return Semantics(
      slider: true,
      value: '${widget.value} characters',
      increasedValue: '${(widget.value + 1).clamp(widget.min, widget.max)} characters',
      decreasedValue: '${(widget.value - 1).clamp(widget.min, widget.max)} characters',
      onIncrease: () {
        if (widget.value < widget.max) widget.onChanged(widget.value + 1);
      },
      onDecrease: () {
        if (widget.value > widget.min) widget.onChanged(widget.value - 1);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = widget.height ?? 260.0;

          return SizedBox(
            width: widget.width,
            height: totalHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (details) =>
                  _onInteractionStart(details.localPosition, totalHeight),
              onVerticalDragUpdate: (details) =>
                  _onInteractionUpdate(details.localPosition, totalHeight),
              onVerticalDragEnd: (_) => _onInteractionEnd(),
              onVerticalDragCancel: () => _onInteractionEnd(),
              onTapDown: (details) {
                _onInteractionStart(details.localPosition, totalHeight);
                _onInteractionEnd();
              },
              child: AnimatedBuilder(
                animation: _interactionController,
                builder: (context, child) {
                  final thumbScale = _thumbScaleAnimation.value;
                  final badgeScale = _badgeScaleAnimation.value;

                  // Normalized progress: 0.0 at bottom (min), 1.0 at top (max)
                  final normalized = (widget.max > widget.min)
                      ? ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0)
                      : 0.0;

                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // --- EXPRESSIVE TRACK CONTAINER ---
                      Container(
                        width: widget.width,
                        height: totalHeight,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkInputSurface
                              : AppColors.lightInputSurface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _isInteracting
                                ? primary.withAlpha(160)
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: _isInteracting ? 1.5 : 1.2,
                          ),
                          boxShadow: _isInteracting
                              ? [
                                  BoxShadow(
                                    color: primary.withAlpha(isDark ? 40 : 25),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ladder Rungs
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(13, (index) {
                                final rungFraction = 1.0 - (index / 12.0);
                                final isMajor = index % 3 == 0;
                                final isNearThumb = (rungFraction - normalized).abs() < 0.12;

                                return AnimatedContainer(
                                  duration: ExpressiveMotion.durationShort3,
                                  height: 2.2,
                                  width: isMajor
                                      ? (isNearThumb ? 32 : 24)
                                      : (isNearThumb ? 18 : 12),
                                  decoration: BoxDecoration(
                                    color: isNearThumb
                                        ? primary.withAlpha(200)
                                        : (isMajor
                                            ? (isDark ? Colors.white24 : Colors.black26)
                                            : (isDark ? Colors.white12 : Colors.black12)),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                );
                              }),
                            ),

                            // Active Indicator Thumb (Medium-thick expressive pill)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Align(
                                alignment: Alignment(
                                  0.0,
                                  1.0 - (2.0 * normalized),
                                ),
                                child: Transform.scale(
                                  scale: thumbScale,
                                  child: Container(
                                    width: 46,
                                    height: _isInteracting ? 10 : 7,
                                    decoration: BoxDecoration(
                                      color: primary,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withAlpha(isDark ? 180 : 130),
                                          blurRadius: _isInteracting ? 14 : 8,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- LATERAL FLOATING BADGE (POPS UP ON TOUCH) ---
                      if (badgeScale > 0.01)
                        Positioned(
                          right: widget.width + 10,
                          top: ((1.0 - normalized) * (totalHeight - 40)).clamp(0.0, totalHeight - 32),
                          child: Opacity(
                            opacity: badgeScale.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: badgeScale,
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCardSurface : primary,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? primary.withAlpha(120) : Colors.white30,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(90),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.labelFormatter?.call(widget.value) ??
                                      '${widget.value} chars',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextPrimary : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
