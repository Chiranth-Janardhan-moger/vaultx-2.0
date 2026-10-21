import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/expressive_motion.dart';

enum ExpressiveIconButtonVariant {
  standard,
  filled,
  filledTonal,
  outlined,
}

enum ExpressiveIconSize {
  small,
  medium,
  large,
}

/// Material 3 Expressive Icon Button with tactile spring physics,
/// continuous rounded container shapes, and micro-interaction animations.
class ExpressiveIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final ExpressiveIconButtonVariant variant;
  final ExpressiveIconSize size;
  final Color? color;
  final Color? customColor;
  final Color? foregroundColor;
  final bool isSelected;
  final Widget? selectedIcon;
  final bool isCircle;
  final bool enableSpringRotation;
  final Widget? badge;
  final bool enableHaptics;

  const ExpressiveIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.variant = ExpressiveIconButtonVariant.standard,
    this.size = ExpressiveIconSize.medium,
    this.color,
    this.customColor,
    this.foregroundColor,
    this.isSelected = false,
    this.selectedIcon,
    this.isCircle = false,
    this.enableSpringRotation = false,
    this.badge,
    this.enableHaptics = true,
  });

  const ExpressiveIconButton.filled({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.size = ExpressiveIconSize.medium,
    this.color,
    this.customColor,
    this.foregroundColor,
    this.isSelected = false,
    this.selectedIcon,
    this.isCircle = false,
    this.enableSpringRotation = false,
    this.badge,
    this.enableHaptics = true,
  }) : variant = ExpressiveIconButtonVariant.filled;

  const ExpressiveIconButton.tonal({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.size = ExpressiveIconSize.medium,
    this.color,
    this.customColor,
    this.foregroundColor,
    this.isSelected = false,
    this.selectedIcon,
    this.isCircle = false,
    this.enableSpringRotation = false,
    this.badge,
    this.enableHaptics = true,
  }) : variant = ExpressiveIconButtonVariant.filledTonal;

  const ExpressiveIconButton.outlined({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.size = ExpressiveIconSize.medium,
    this.color,
    this.customColor,
    this.foregroundColor,
    this.isSelected = false,
    this.selectedIcon,
    this.isCircle = false,
    this.enableSpringRotation = false,
    this.badge,
    this.enableHaptics = true,
  }) : variant = ExpressiveIconButtonVariant.outlined;

  @override
  State<ExpressiveIconButton> createState() => _ExpressiveIconButtonState();
}

class _ExpressiveIconButtonState extends State<ExpressiveIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ExpressiveMotion.durationShort2,
      reverseDuration: ExpressiveMotion.durationMedium3,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: ExpressiveMotion.iconButtonPressScale,
    ).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: ExpressiveMotion.snappy,
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.08, // Subtle ~4.5 degree twist on press
    ).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: ExpressiveMotion.snappy,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    _pressController.reverse();
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;

    // Dimensions based on size tier
    double containerDimension;
    double iconDimension;
    double cornerRadius;

    switch (widget.size) {
      case ExpressiveIconSize.small:
        containerDimension = 36.0;
        iconDimension = 18.0;
        cornerRadius = 12.0;
        break;
      case ExpressiveIconSize.medium:
        containerDimension = 46.0;
        iconDimension = 22.0;
        cornerRadius = 16.0;
        break;
      case ExpressiveIconSize.large:
        containerDimension = 54.0;
        iconDimension = 26.0;
        cornerRadius = 18.0;
        break;
    }

    final primary = widget.customColor ?? widget.color ?? AppColors.primaryBlue;

    Color backgroundColor;
    Color iconColor;
    BorderSide borderSide = BorderSide.none;

    if (!isEnabled) {
      backgroundColor = Colors.transparent;
      iconColor = isDark ? AppColors.darkTextMuted.withAlpha(100) : AppColors.lightTextMuted.withAlpha(100);
    } else {
      switch (widget.variant) {
        case ExpressiveIconButtonVariant.filled:
          backgroundColor = widget.isSelected
              ? primary
              : (isDark ? primary.withAlpha(200) : primary);
          iconColor = widget.foregroundColor ?? Colors.white;
          break;
        case ExpressiveIconButtonVariant.filledTonal:
          backgroundColor = widget.isSelected
              ? (isDark ? primary.withAlpha(100) : primary.withAlpha(60))
              : (isDark ? primary.withAlpha(45) : primary.withAlpha(28));
          iconColor = widget.foregroundColor ?? (isDark ? Colors.white : primary);
          break;
        case ExpressiveIconButtonVariant.outlined:
          backgroundColor = _isHovered
              ? (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10))
              : Colors.transparent;
          iconColor = widget.foregroundColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
          borderSide = BorderSide(
            color: widget.isSelected
                ? primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1.2,
          );
          break;
        case ExpressiveIconButtonVariant.standard:
          backgroundColor = _isHovered
              ? (isDark ? Colors.white.withAlpha(18) : primary.withAlpha(20))
              : Colors.transparent;
          iconColor = widget.foregroundColor ??
              (widget.isSelected
                  ? primary
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary));
          break;
      }
    }

    final activeIcon = (widget.isSelected && widget.selectedIcon != null)
        ? widget.selectedIcon!
        : widget.icon;

    Widget iconWidget = IconTheme(
      data: IconThemeData(
        color: iconColor,
        size: iconDimension,
      ),
      child: activeIcon,
    );

    Widget containerWidget = AnimatedContainer(
      duration: ExpressiveMotion.durationShort3,
      curve: ExpressiveMotion.emphasized,
      width: containerDimension,
      height: containerDimension,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.isCircle ? null : BorderRadius.circular(cornerRadius),
        border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
      ),
      child: Center(child: iconWidget),
    );

    if (widget.badge != null) {
      containerWidget = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          containerWidget,
          Positioned(
            top: 2,
            right: 2,
            child: widget.badge!,
          ),
        ],
      );
    }

    Widget result = AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        Widget transformed = Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
        if (widget.enableSpringRotation) {
          transformed = Transform.rotate(
            angle: _rotationAnimation.value * math.pi,
            child: transformed,
          );
        }
        return transformed;
      },
      child: containerWidget,
    );

    result = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isEnabled ? widget.onPressed : null,
        child: result,
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(
        message: widget.tooltip!,
        child: result,
      );
    }

    return result;
  }
}

/// Material 3 Expressive Animated Toggle Icon (e.g. for visibility, lock/unlock, copy/check)
class ExpressiveToggleIcon extends StatefulWidget {
  final bool isToggled;
  final ValueChanged<bool>? onToggle;
  final IconData firstIcon;
  final IconData secondIcon;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  final String? tooltip;

  const ExpressiveToggleIcon({
    super.key,
    required this.isToggled,
    this.onToggle,
    required this.firstIcon,
    required this.secondIcon,
    this.activeColor,
    this.inactiveColor,
    this.size = 22.0,
    this.tooltip,
  });

  @override
  State<ExpressiveToggleIcon> createState() => _ExpressiveToggleIconState();
}

class _ExpressiveToggleIconState extends State<ExpressiveToggleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ExpressiveMotion.durationMedium2,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.65).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.65, end: 1.0).chain(
          CurveTween(curve: ExpressiveMotion.snappy),
        ),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant ExpressiveToggleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isToggled != widget.isToggled) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isToggled
        ? (widget.activeColor ?? AppColors.primaryBlue)
        : (widget.inactiveColor ??
            (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted));

    Widget content = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            widget.isToggled ? widget.secondIcon : widget.firstIcon,
            key: ValueKey<bool>(widget.isToggled),
            size: widget.size,
            color: color,
          ),
        );
      },
    );

    if (widget.onToggle != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onToggle!(!widget.isToggled);
        },
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: content,
        ),
      );
    }

    if (widget.tooltip != null) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }

    return content;
  }
}

/// Material 3 Expressive Tonal Container for displaying category/service icons
class ExpressiveIconContainer extends StatelessWidget {
  final Widget icon;
  final Color? color;
  final double size;
  final double borderRadius;
  final bool hasBorder;

  const ExpressiveIconContainer({
    super.key,
    required this.icon,
    this.color,
    this.size = 48.0,
    this.borderRadius = 16.0,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = color ?? AppColors.primaryBlue;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? primary.withAlpha(40) : primary.withAlpha(24),
        borderRadius: BorderRadius.circular(borderRadius),
        border: hasBorder
            ? Border.all(
                color: isDark ? primary.withAlpha(70) : primary.withAlpha(50),
                width: 1.2,
              )
            : null,
      ),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            color: isDark ? primary : primary,
            size: size * 0.5,
          ),
          child: icon,
        ),
      ),
    );
  }
}
