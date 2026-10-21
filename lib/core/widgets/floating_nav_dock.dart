import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vaultx/core/theme/app_theme.dart';

enum NavTab { passwords, wallet, generator, settings }

// ─────────────────────────────────────────────────────────────
// Data for each tab
// ─────────────────────────────────────────────────────────────
const _kTabs = [
  _TabData(NavTab.passwords, Icons.vpn_key_rounded, Icons.vpn_key_outlined, 'Passwords'),
  _TabData(NavTab.wallet, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Wallet'),
  _TabData(NavTab.generator, Icons.auto_awesome_rounded, Icons.auto_awesome_outlined, 'Generator'),
  _TabData(NavTab.settings, Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
];

class _TabData {
  final NavTab tab;
  final IconData filledIcon;
  final IconData outlinedIcon;
  final String label;
  const _TabData(this.tab, this.filledIcon, this.outlinedIcon, this.label);
}

// ─────────────────────────────────────────────────────────────
// FloatingNavDock — M3 Expressive spring-sliding pill nav bar
// ─────────────────────────────────────────────────────────────
class FloatingNavDock extends StatefulWidget {
  final NavTab currentTab;
  final ValueChanged<NavTab> onTabSelected;

  const FloatingNavDock({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  State<FloatingNavDock> createState() => _FloatingNavDockState();
}

class _FloatingNavDockState extends State<FloatingNavDock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pillPosition; // 0.0 → 3.0 (tab index as double)

  int _prevIndex = 0;
  int _targetIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = _tabIndex(widget.currentTab);
    _targetIndex = _prevIndex;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pillPosition = Tween<double>(
      begin: _prevIndex.toDouble(),
      end: _targetIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void didUpdateWidget(FloatingNavDock old) {
    super.didUpdateWidget(old);
    final newIndex = _tabIndex(widget.currentTab);
    if (newIndex != _targetIndex) {
      _animateTo(newIndex);
    }
  }

  void _animateTo(int newIndex) {
    // Capture current animated value as new starting point
    final currentPos = _pillPosition.value;
    _prevIndex = _targetIndex;
    _targetIndex = newIndex;

    _pillPosition = Tween<double>(
      begin: currentPos,
      end: newIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward(from: 0.0);
  }

  int _tabIndex(NavTab tab) => _kTabs.indexWhere((t) => t.tab == tab);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xEE1A1D21)
        : const Color(0xF5FFFFFF);
    final borderColor = isDark
        ? Colors.white.withAlpha(22)
        : Colors.black.withAlpha(18);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 20, right: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 90 : 28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final tabWidth = totalWidth / _kTabs.length;

                  return AnimatedBuilder(
                    animation: _pillPosition,
                    builder: (context, _) {
                      final pos = _pillPosition.value;
                      return Stack(
                        children: [
                          // ── Sliding filled pill indicator ──────────────
                          Positioned(
                            top: 6,
                            bottom: 6,
                            left: pos * tabWidth + 6,
                            width: tabWidth - 12,
                            child: const _SlidingPill(),
                          ),

                          // ── Tab items ──────────────────────────────────
                          Row(
                            children: List.generate(_kTabs.length, (i) {
                              final tab = _kTabs[i];
                              final isSelected =
                                  widget.currentTab == tab.tab;
                              // How "selected" is this tab (0→1) for icon morph
                              final selectedness =
                                  (1.0 - (pos - i).abs()).clamp(0.0, 1.0);

                              return Expanded(
                                child: _NavItem(
                                  tabData: tab,
                                  isSelected: isSelected,
                                  selectedness: selectedness,
                                  onTap: () =>
                                      widget.onTabSelected(tab.tab),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sliding filled pill (drawn behind the icons)
// ─────────────────────────────────────────────────────────────
class _SlidingPill extends StatelessWidget {
  const _SlidingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Single nav tab item
// ─────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final _TabData tabData;
  final bool isSelected;
  final double selectedness; // 0.0 → 1.0 (drives continuous morph)
  final VoidCallback onTap;

  const _NavItem({
    required this.tabData,
    required this.isSelected,
    required this.selectedness,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.selectedness;

    // Icon color: white when selected (on blue pill), muted when unselected
    final inactiveIconColor = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
    final iconColor = Color.lerp(inactiveIconColor, Colors.white, s)!;

    // Label fades in as selectedness → 1
    final labelOpacity = (s * 2 - 1).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.tabData.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon — morphs between outlined and filled
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    s > 0.5
                        ? widget.tabData.filledIcon
                        : widget.tabData.outlinedIcon,
                    key: ValueKey(s > 0.5),
                    size: 22,
                    color: iconColor,
                  ),
                ),

                // Label — slides up & fades in when selected
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: widget.isSelected ? 16 : 0,
                  child: Opacity(
                    opacity: labelOpacity.clamp(0.0, 1.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.tabData.label,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
