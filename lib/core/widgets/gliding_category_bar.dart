import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind, lerpDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/theme/app_theme.dart';

/// Data model representing an item in the [GlidingCategoryBar].
class GlidingCategoryItem {
  final String id;
  final String label;
  final int? count;
  final IconData? icon;
  final Color? dotColor;
  final VoidCallback? onLongPress;
  final String? tooltip;

  const GlidingCategoryItem({
    required this.id,
    required this.label,
    this.count,
    this.icon,
    this.dotColor,
    this.onLongPress,
    this.tooltip,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlidingCategoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          count == other.count &&
          icon == other.icon &&
          dotColor == other.dotColor;

  @override
  int get hashCode => Object.hash(id, label, count, icon, dotColor);
}

/// Custom scroll behavior enabling mouse-drag, touch, and trackpad gestures on all platforms.
class GlidingScrollBehavior extends MaterialScrollBehavior {
  const GlidingScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Apple HIG & OriginOS-style Gliding Magnetic Category Pill Bar.
///
/// Features:
/// - Single liquid morphing pill indicator that glides beneath the active category.
/// - Dynamic width adaptation matching text length and micro-counter badges.
/// - Auto-centering scroll physics using [Curves.easeOutCubic].
/// - Tactile haptic feedback on selection transitions.
/// - Dual-platform support: native touch flings on Android and mouse-drag/wheel scroll on Windows.
class GlidingCategoryBar extends StatefulWidget {
  final List<GlidingCategoryItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsetsGeometry padding;
  final double height;
  final Color? indicatorColor;
  final bool enableHaptics;
  final bool autoCenter;

  const GlidingCategoryBar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.trailing,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    this.height = 42,
    this.indicatorColor,
    this.enableHaptics = true,
    this.autoCenter = true,
  });

  @override
  State<GlidingCategoryBar> createState() => _GlidingCategoryBarState();
}

class _GlidingCategoryBarState extends State<GlidingCategoryBar>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {};

  late AnimationController _animController;
  late Animation<double> _glideAnimation;

  // Stored Rects in the local content coordinate space of _stackKey
  final Map<String, Rect> _itemRects = {};
  Rect _currentRect = Rect.zero;
  Rect _prevRect = Rect.zero;
  Rect _targetRect = Rect.zero;
  bool _hasMeasured = false;

  @override
  void initState() {
    super.initState();
    _syncItemKeys();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _glideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    )..addListener(() {
        setState(() {
          _updateInterpolatedRect(_glideAnimation.value);
        });
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureAllItems(initial: true);
    });
  }

  @override
  void didUpdateWidget(GlidingCategoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItemKeys();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureAllItems(initial: false);

      if (oldWidget.selectedId.toLowerCase() != widget.selectedId.toLowerCase()) {
        _animateToSelected();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncItemKeys() {
    for (final item in widget.items) {
      _itemKeys.putIfAbsent(item.id, () => GlobalKey());
    }
  }

  void _measureAllItems({required bool initial}) {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;

    final newRects = <String, Rect>{};
    for (final item in widget.items) {
      final key = _itemKeys[item.id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero, ancestor: stackBox);
        newRects[item.id.toLowerCase()] = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          box.size.width,
          box.size.height,
        );
      }
    }

    _itemRects.clear();
    _itemRects.addAll(newRects);

    final selectedKey = widget.selectedId.toLowerCase();
    final matchedRect = _itemRects[selectedKey];

    if (matchedRect != null) {
      if (initial || !_hasMeasured) {
        _currentRect = matchedRect;
        _prevRect = matchedRect;
        _targetRect = matchedRect;
        _hasMeasured = true;
        setState(() {});
        if (widget.autoCenter) {
          _autoCenterSelected(immediate: true);
        }
      } else if (_targetRect != matchedRect && !_animController.isAnimating) {
        _animateToSelected();
      }
    }
  }

  void _animateToSelected() {
    final selectedKey = widget.selectedId.toLowerCase();
    final target = _itemRects[selectedKey];
    if (target == null) return;

    _prevRect = _currentRect.isEmpty ? target : _currentRect;
    _targetRect = target;

    _animController.forward(from: 0.0);

    if (widget.autoCenter) {
      _autoCenterSelected();
    }
  }

  void _updateInterpolatedRect(double progress) {
    if (_prevRect.isEmpty || _targetRect.isEmpty) {
      _currentRect = _targetRect;
      return;
    }

    final distance = _targetRect.center.dx - _prevRect.center.dx;

    // OriginOS liquid stretch momentum: stretches horizontally during peak velocity (progress ~0.5)
    final stretchFactor = math.sin(progress * math.pi) *
        (distance.abs() * 0.10).clamp(0.0, 16.0);

    final left = lerpDouble(_prevRect.left, _targetRect.left, progress)! -
        (distance > 0 ? 0.0 : stretchFactor);
    final width = lerpDouble(_prevRect.width, _targetRect.width, progress)! +
        stretchFactor;
    final top = lerpDouble(_prevRect.top, _targetRect.top, progress)!;
    final height = lerpDouble(_prevRect.height, _targetRect.height, progress)!;

    _currentRect = Rect.fromLTWH(left, top, width, height);
  }

  void _autoCenterSelected({bool immediate = false}) {
    if (!widget.autoCenter || !_scrollController.hasClients) return;

    final selectedKey = widget.selectedId.toLowerCase();
    final rect = _itemRects[selectedKey];
    if (rect == null) return;

    final viewportWidth = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetScrollOffset =
        (rect.center.dx - (viewportWidth / 2)).clamp(0.0, maxScroll);

    if (immediate) {
      _scrollController.jumpTo(targetScrollOffset);
    } else {
      _scrollController.animateTo(
        targetScrollOffset,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleItemTap(GlidingCategoryItem item) {
    if (widget.enableHaptics) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
    widget.onSelected(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = widget.indicatorColor ?? AppColors.primaryBlue;

    return SizedBox(
      height: widget.height,
      child: ScrollConfiguration(
        behavior: const GlidingScrollBehavior(),
        child: Listener(
          // Translate vertical desktop mouse-wheel scrolls into horizontal offsets
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent && _scrollController.hasClients) {
              final delta = pointerSignal.scrollDelta.dy != 0
                  ? pointerSignal.scrollDelta.dy
                  : pointerSignal.scrollDelta.dx;
              final newOffset = (_scrollController.offset + delta)
                  .clamp(0.0, _scrollController.position.maxScrollExtent);
              _scrollController.jumpTo(newOffset);
            }
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: widget.padding,
            child: Stack(
              key: _stackKey,
              clipBehavior: Clip.none,
              children: [
                // ── 1. The Morphing Liquid Sliding Pill Indicator ──
                if (_hasMeasured && !_currentRect.isEmpty)
                  Positioned(
                    left: _currentRect.left,
                    top: _currentRect.top,
                    width: _currentRect.width,
                    height: _currentRect.height,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primaryAccent,
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            primaryAccent,
                            primaryAccent.withAlpha(235),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryAccent.withAlpha(isDark ? 85 : 55),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── 2. Interactive Category Pills Row ──
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 8),
                    ],
                    for (int i = 0; i < widget.items.length; i++) ...[
                      _CategoryItemWidget(
                        key: _itemKeys[widget.items[i].id],
                        item: widget.items[i],
                        isSelected: widget.selectedId.toLowerCase() ==
                            widget.items[i].id.toLowerCase(),
                        isDark: isDark,
                        onTap: () => _handleItemTap(widget.items[i]),
                      ),
                      if (i < widget.items.length - 1) const SizedBox(width: 8),
                    ],
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryItemWidget extends StatefulWidget {
  final GlidingCategoryItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_CategoryItemWidget> createState() => _CategoryItemWidgetState();
}

class _CategoryItemWidgetState extends State<_CategoryItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isDark = widget.isDark;

    final unselectedBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final unselectedBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final unselectedText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: widget.item.tooltip ?? widget.item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.item.onLongPress,
          onSecondaryTap: widget.item.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.transparent
                  : (_isHovered
                      ? (isDark
                          ? AppColors.darkCardSurface.withAlpha(240)
                          : const Color(0xFFF1F5F9))
                      : unselectedBg),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.transparent : unselectedBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Leading Icon / Favorite Star
                if (widget.item.icon != null) ...[
                  Icon(
                    widget.item.icon,
                    size: 15,
                    color: isSelected
                        ? Colors.white
                        : (widget.item.icon == Icons.star_rounded
                            ? Colors.amber
                            : unselectedText),
                  ),
                  const SizedBox(width: 5),
                ] else if (widget.item.dotColor != null) ...[
                  // Category accent dot (e.g. Google blue, Banking green)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : widget.item.dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Category Text Label
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.2,
                    color: isSelected ? Colors.white : unselectedText,
                  ),
                ),

                // Micro-Counter Badge (omitted when 0 to avoid visual clutter)
                if (widget.item.count != null && widget.item.count! > 0) ...[
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withAlpha(46)
                          : (isDark
                              ? Colors.white.withAlpha(18)
                              : Colors.black.withAlpha(12)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.item.count}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
