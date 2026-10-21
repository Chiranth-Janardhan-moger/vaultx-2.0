import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/expressive_motion.dart';

enum ExpressiveButtonVariant {
  filled,
  filledTonal,
  elevated,
  outlined,
  text,
}

enum ExpressiveButtonSize {
  compact,
  medium,
  large,
}

/// Material 3 Expressive Button with tactile spring physics,
/// shape morphing press states, and expressive elevation.
class ExpressiveButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final Widget? icon;
  final Widget? trailingIcon;
  final ExpressiveButtonVariant variant;
  final ExpressiveButtonSize size;
  final Color? customColor;
  final Color? foregroundColor;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double? height;
  final BorderRadius? customBorderRadius;
  final bool enableHaptics;

  const ExpressiveButton({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.trailingIcon,
    this.variant = ExpressiveButtonVariant.filled,
    this.size = ExpressiveButtonSize.medium,
    this.customColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.customBorderRadius,
    this.enableHaptics = true,
  }) : assert(child != null || label != null, 'Either child or label must be provided.');

  const ExpressiveButton.filled({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.trailingIcon,
    this.size = ExpressiveButtonSize.medium,
    this.customColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.customBorderRadius,
    this.enableHaptics = true,
  }) : variant = ExpressiveButtonVariant.filled;

  const ExpressiveButton.tonal({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.trailingIcon,
    this.size = ExpressiveButtonSize.medium,
    this.customColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.customBorderRadius,
    this.enableHaptics = true,
  }) : variant = ExpressiveButtonVariant.filledTonal;

  const ExpressiveButton.outlined({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.trailingIcon,
    this.size = ExpressiveButtonSize.medium,
    this.customColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.customBorderRadius,
    this.enableHaptics = true,
  }) : variant = ExpressiveButtonVariant.outlined;

  const ExpressiveButton.elevated({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.trailingIcon,
    this.size = ExpressiveButtonSize.medium,
    this.customColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.customBorderRadius,
    this.enableHaptics = true,
  }) : variant = ExpressiveButtonVariant.elevated;

  const ExpressiveButton.text({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.trailingIcon,
    this.size = ExpressiveButtonSize.medium,
    this.customColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.customBorderRadius,
    this.enableHaptics = true,
  }) : variant = ExpressiveButtonVariant.text;

  @override
  State<ExpressiveButton> createState() => _ExpressiveButtonState();
}

class _ExpressiveButtonState extends State<ExpressiveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ExpressiveMotion.durationShort2,
      reverseDuration: ExpressiveMotion.durationMedium2,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: ExpressiveMotion.buttonPressScale,
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
    if (widget.onPressed == null || widget.isLoading) return;
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null || widget.isLoading) return;
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
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    // Dimensions
    double defaultHeight;
    double horizontalPadding;
    double fontSize;
    double iconSize;
    double borderRadiusValue;

    switch (widget.size) {
      case ExpressiveButtonSize.compact:
        defaultHeight = 40.0;
        horizontalPadding = 16.0;
        fontSize = 13.0;
        iconSize = 16.0;
        borderRadiusValue = 16.0;
        break;
      case ExpressiveButtonSize.medium:
        defaultHeight = 48.0;
        horizontalPadding = 20.0;
        fontSize = 15.0;
        iconSize = 20.0;
        borderRadiusValue = 22.0;
        break;
      case ExpressiveButtonSize.large:
        defaultHeight = 56.0;
        horizontalPadding = 24.0;
        fontSize = 16.0;
        iconSize = 22.0;
        borderRadiusValue = 26.0;
        break;
    }

    final effectiveHeight = widget.height ?? defaultHeight;
    final effectiveBorderRadius = widget.customBorderRadius ??
        BorderRadius.circular(borderRadiusValue);

    // Color derivation
    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide = BorderSide.none;
    List<BoxShadow> shadows = [];

    final primary = widget.customColor ?? AppColors.primaryBlue;

    if (!isEnabled) {
      backgroundColor = isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20);
      foregroundColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    } else {
      switch (widget.variant) {
        case ExpressiveButtonVariant.filled:
          backgroundColor = primary;
          foregroundColor = widget.foregroundColor ?? Colors.white;
          shadows = [
            BoxShadow(
              color: primary.withAlpha(isDark ? 90 : 70),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ];
          break;
        case ExpressiveButtonVariant.filledTonal:
          backgroundColor = isDark
              ? primary.withAlpha(55)
              : primary.withAlpha(35);
          foregroundColor = widget.foregroundColor ??
              (isDark ? Colors.white : primary);
          break;
        case ExpressiveButtonVariant.elevated:
          backgroundColor = isDark
              ? AppColors.darkCardSurface
              : AppColors.lightCardSurface;
          foregroundColor = widget.foregroundColor ??
              (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
          shadows = [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 80 : 30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ];
          break;
        case ExpressiveButtonVariant.outlined:
          backgroundColor = _isHovered
              ? (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10))
              : Colors.transparent;
          foregroundColor = widget.foregroundColor ??
              (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
          borderSide = BorderSide(
            color: widget.customColor ??
                (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1.4,
          );
          break;
        case ExpressiveButtonVariant.text:
          backgroundColor = _isHovered
              ? (isDark ? Colors.white.withAlpha(15) : primary.withAlpha(20))
              : Colors.transparent;
          foregroundColor = widget.foregroundColor ?? primary;
          break;
      }
    }

    Widget content;
    if (widget.isLoading) {
      content = SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else {
      final children = <Widget>[];

      if (widget.icon != null) {
        children.add(
          IconTheme(
            data: IconThemeData(
              color: foregroundColor,
              size: iconSize,
            ),
            child: widget.icon!,
          ),
        );
      }

      if (widget.label != null) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(width: 8));
        }
        children.add(
          Flexible(
            child: Text(
              widget.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      } else if (widget.child != null) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(width: 8));
        }
        children.add(widget.child!);
      }

      if (widget.trailingIcon != null) {
        children.add(const SizedBox(width: 8));
        children.add(
          IconTheme(
            data: IconThemeData(
              color: foregroundColor,
              size: iconSize,
            ),
            child: widget.trailingIcon!,
          ),
        );
      }

      content = Row(
        mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    }

    Widget button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: AnimatedContainer(
        duration: ExpressiveMotion.durationShort4,
        curve: ExpressiveMotion.emphasized,
        height: effectiveHeight,
        width: widget.width,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: effectiveBorderRadius,
          border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
          boxShadow: shadows,
        ),
        child: Center(
          widthFactor: widget.isFullWidth ? null : 1.0,
          child: content,
        ),
      ),
    );

    button = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isEnabled ? widget.onPressed : null,
        child: button,
      ),
    );

    if (widget.isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

/// Material 3 Expressive Segmented Button with sliding spring indicator
class ExpressiveSegmentedButton<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onSelected;
  final Widget Function(BuildContext context, T item, bool isSelected) itemBuilder;
  final double height;
  final EdgeInsetsGeometry padding;

  const ExpressiveSegmentedButton({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.itemBuilder,
    this.height = 46.0,
    this.padding = const EdgeInsets.all(4.0),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = items.indexOf(selectedItem);

    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = items.length;
          final segmentWidth = constraints.maxWidth / count;

          return Stack(
            children: [
              // Expressive Spring Pill Indicator
              AnimatedPositioned(
                duration: ExpressiveMotion.durationMedium2,
                curve: ExpressiveMotion.emphasized,
                left: (selectedIndex >= 0 ? selectedIndex : 0) * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardSurface : Colors.white,
                    borderRadius: BorderRadius.circular((height - 8) / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 80 : 25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Segment items
              Row(
                children: List.generate(count, (index) {
                  final item = items[index];
                  final isSelected = item == selectedItem;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isSelected) {
                          HapticFeedback.selectionClick();
                          onSelected(item);
                        }
                      },
                      child: Center(
                        child: itemBuilder(context, item, isSelected),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
