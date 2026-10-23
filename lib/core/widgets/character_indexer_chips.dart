import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/pressable_scale.dart';

/// Interactive Character Position Indexer.
///
/// Designed for banking, VPNs, and security challenges requiring users to input
/// random single characters (e.g., "Enter 2nd, 4th, and 5th characters of your memorable word / PIN").
///
/// Renders high-contrast, tactile indexed chips [ 1:c ] [ 2:U ] [ 3:d ] [ 4:X ] [ 5:a ].
/// Tapping any chip copies strictly that single character to the secure clipboard
/// with automatic 30s auto-clear and tactile feedback.
class CharacterIndexerChips extends StatefulWidget {
  final String secret;
  final bool isRevealed;
  final String? label;
  final ValueChanged<String>? onCharacterCopied;

  const CharacterIndexerChips({
    super.key,
    required this.secret,
    this.isRevealed = true,
    this.label,
    this.onCharacterCopied,
  });

  @override
  State<CharacterIndexerChips> createState() => _CharacterIndexerChipsState();
}

class _CharacterIndexerChipsState extends State<CharacterIndexerChips> {
  int? _recentlyCopiedIndex;
  Timer? _copiedResetTimer;

  void _copyCharacter(int index, String char) {
    HapticFeedback.lightImpact();
    ClipboardSecurityService.copySecure(
      context: context,
      ref: null,
      text: char,
      label: 'Character #${index + 1}',
      isSensitive: true,
    );

    setState(() {
      _recentlyCopiedIndex = index;
    });

    widget.onCharacterCopied?.call(char);

    _copiedResetTimer?.cancel();
    _copiedResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _recentlyCopiedIndex = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.secret.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textCol = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final chars = widget.secret.split('');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.format_list_numbered_rounded,
                  size: 13,
                  color: mutedCol,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: mutedCol,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap chip to copy',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: mutedCol.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(chars.length, (index) {
              final char = chars[index];
              final isCopied = _recentlyCopiedIndex == index;

              return Padding(
                padding: EdgeInsets.only(right: index == chars.length - 1 ? 0 : 6),
                child: PressableScale(
                  onTap: () => _copyCharacter(index, char),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCopied
                          ? const Color(0xFF10B981).withAlpha(isDark ? 45 : 30)
                          : cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCopied
                            ? const Color(0xFF10B981)
                            : borderCol,
                        width: isCopied ? 1.5 : 1.0,
                      ),
                      boxShadow: isCopied
                          ? [
                              BoxShadow(
                                color: const Color(0xFF10B981).withAlpha(isDark ? 80 : 50),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCopied ? const Color(0xFF10B981) : mutedCol,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isRevealed ? char : '●',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isCopied
                                ? const Color(0xFF10B981)
                                : textCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
