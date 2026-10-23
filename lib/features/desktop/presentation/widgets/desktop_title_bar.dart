import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/vault/presentation/vault_watchtower_sheet.dart';

class DesktopTitleBar extends ConsumerWidget {
  final VoidCallback onOpenCommandPalette;

  const DesktopTitleBar({
    super.key,
    required this.onOpenCommandPalette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultState = ref.watch(vaultPasswordsProvider);
    final report = VaultWatchtowerEngine.audit(vaultState.allEntries);

    final bgColor = isDark
        ? const Color(0xDD0D1117)
        : const Color(0xEEF8FAFC);
    final borderCol = isDark
        ? const Color(0x1FFFFFFF)
        : const Color(0x1F000000);
    final textMuted = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderCol, width: 1)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // App Monogram / Brand Logo
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.brandPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text(
                  'VaultX',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),

                // Offline Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withAlpha(isDark ? 30 : 20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emerald500.withAlpha(70)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emerald500,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '100% Local Vault',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.emerald400 : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Central Omnibar Launcher Trigger Button (Responsive Flex)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onOpenCommandPalette,
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E222A)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 15, color: textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Search vault or run command...',
                                    style: TextStyle(fontSize: 12, color: textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Ctrl K',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: textMuted,
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

                const SizedBox(width: 12),

                // Security Watchtower Health Pill
                Tooltip(
                  message: 'Security Audit (${report.healthScore}%)',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const VaultWatchtowerSheet(),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            size: 16,
                            color: report.healthScore >= 80
                                ? AppColors.emerald500
                                : AppColors.amber500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${report.healthScore}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: report.healthScore >= 80
                                  ? AppColors.emerald500
                                  : AppColors.amber500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Lock Vault Button
                Tooltip(
                  message: 'Lock Vault Immediately (Ctrl + L)',
                  child: IconButton(
                    icon: const Icon(Icons.lock_outline_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ref.read(authSessionProvider.notifier).lockVault();
                      HappyFeedback.show(context, message: 'Vault locked');
                    },
                  ),
                ),

                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: borderCol),
                const SizedBox(width: 8),

                // Windows Native-Style Caption Buttons
                _WindowCaptionButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Minimize',
                  onPressed: () {},
                ),
                _WindowCaptionButton(
                  icon: Icons.crop_square_rounded,
                  tooltip: 'Maximize',
                  onPressed: () {},
                ),
                _WindowCaptionButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  isClose: true,
                  onPressed: () => SystemNavigator.pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowCaptionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowCaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<_WindowCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverBg = widget.isClose
        ? const Color(0xFFE81123)
        : (isDark ? Colors.white12 : Colors.black12);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 38,
          height: 30,
          color: _isHovered ? hoverBg : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 14,
            color: widget.isClose && _isHovered
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }
}
