import 'package:flutter/material.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/expressive_motion.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';

/// Material 3 Expressive Swipe-to-Action Motion Slider.
/// Features dynamic fill progress, spring return physics,
/// morphing thumb icon, and tactile haptic feedback.
class ExpressiveSwipeSlider extends StatefulWidget {
  final VoidCallback onTrigger;
  final String label;
  final IconData leadingIcon;
  final IconData completedIcon;
  final Color? activeColor;
  final Color? completedColor;
  final double height;

  const ExpressiveSwipeSlider({
    super.key,
    required this.onTrigger,
    this.label = 'Swipe to Confirm',
    this.leadingIcon = Icons.arrow_forward_rounded,
    this.completedIcon = Icons.check_rounded,
    this.activeColor,
    this.completedColor,
    this.height = 58.0,
  });

  @override
  State<ExpressiveSwipeSlider> createState() => _ExpressiveSwipeSliderState();
}

class _ExpressiveSwipeSliderState extends State<ExpressiveSwipeSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _springAnimation;

  double _dragPosition = 0.0;
  bool _isCompleted = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: ExpressiveMotion.durationMedium3,
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _resetWithSpring(double from) {
    _springAnimation = Tween<double>(begin: from, end: 0.0).animate(
      CurvedAnimation(
        parent: _springController,
        curve: ExpressiveMotion.snappy,
      ),
    )..addListener(() {
        setState(() {
          _dragPosition = _springAnimation.value;
        });
      });
    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.activeColor ?? AppColors.primaryBlue;
    final completedCol = widget.completedColor ?? AppColors.emerald500;
    final trackColor = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

    final thumbSize = widget.height - 8;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - widget.height;
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: _isDragging
                  ? primary.withAlpha(120)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // Dynamic Fill Track
              if (_dragPosition > 0 || _isCompleted)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: (_dragPosition + widget.height).clamp(0.0, constraints.maxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isCompleted
                          ? completedCol.withAlpha(60)
                          : primary.withAlpha(50),
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),

              // Centered Shimmering Label
              Center(
                child: Opacity(
                  opacity: (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 52),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Draggable Spring Thumb
              Positioned(
                left: _dragPosition + 4,
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    if (_isCompleted) return;
                    _springController.stop();
                    setState(() => _isDragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_isCompleted) return;
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_isCompleted) return;
                    setState(() => _isDragging = false);

                    if (_dragPosition >= maxDrag * 0.72) {
                      // Trigger action
                      setState(() {
                        _dragPosition = maxDrag;
                        _isCompleted = true;
                      });
                      HappyFeedback.vibrate();
                      widget.onTrigger();

                      // Smooth auto reset after 400ms
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (mounted) {
                          setState(() {
                            _isCompleted = false;
                          });
                          _resetWithSpring(maxDrag);
                        }
                      });
                    } else {
                      // Bounce back with spring
                      _resetWithSpring(_dragPosition);
                    }
                  },
                  child: AnimatedContainer(
                    duration: ExpressiveMotion.durationShort3,
                    curve: ExpressiveMotion.emphasized,
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: _isCompleted ? completedCol : primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isCompleted ? completedCol : primary)
                              .withAlpha(isDark ? 160 : 100),
                          blurRadius: _isDragging ? 12 : 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: ExpressiveMotion.durationShort4,
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: child,
                        ),
                        child: Icon(
                          _isCompleted ? widget.completedIcon : widget.leadingIcon,
                          key: ValueKey<bool>(_isCompleted),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
