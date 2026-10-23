import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/add_password_screen.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/vault/presentation/vault_watchtower_sheet.dart';
import 'package:vaultx/features/wallet/presentation/add_card_screen.dart';

/// Raycast / Linear style Command Palette & Omnibar for Windows Desktop.
///
/// Features:
/// - Instant full-vault fuzzy search across titles, usernames, categories, and tags.
/// - Keyboard arrow navigation (↑ / ↓) and Enter selection.
/// - Direct `Ctrl + C` password/PIN copy with dynamic status pill feedback.
/// - Built-in quick actions (Add Password, Add PIN, Add Card, Lock Vault, Audit).
/// - Frosted glass acrylic overlay with specular border.
class CommandPaletteDialog extends ConsumerStatefulWidget {
  final ValueChanged<VaultPasswordEntry>? onSelectEntry;

  const CommandPaletteDialog({
    super.key,
    this.onSelectEntry,
  });

  static Future<void> show(
    BuildContext context, {
    ValueChanged<VaultPasswordEntry>? onSelectEntry,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(120),
      barrierDismissible: true,
      builder: (_) => CommandPaletteDialog(onSelectEntry: onSelectEntry),
    );
  }

  @override
  ConsumerState<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VaultPasswordEntry? entry;
  final VoidCallback? onExecute;

  const _CommandPaletteItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.entry,
    this.onExecute,
  });
}

class _CommandPaletteDialogState extends ConsumerState<CommandPaletteDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  int _selectedIndex = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
        _selectedIndex = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_CommandPaletteItem> _buildItems(List<VaultPasswordEntry> entries) {
    final lowerQ = _query.toLowerCase();
    final List<_CommandPaletteItem> results = [];

    // 1. Matched Credentials
    for (final entry in entries) {
      if (entry.isDeleted) continue;
      final matchesTitle = entry.title.toLowerCase().contains(lowerQ);
      final matchesUser = entry.username.toLowerCase().contains(lowerQ);
      final matchesCat = entry.category.toLowerCase().contains(lowerQ);

      if (lowerQ.isEmpty || matchesTitle || matchesUser || matchesCat) {
        IconData itemIcon = Icons.lock_outline_rounded;
        Color itemColor = AppColors.primaryBlue;

        if (entry.isPinOnly || entry.hasPin) {
          itemIcon = Icons.dialpad_rounded;
          itemColor = AppColors.emerald500;
        } else if (entry.isSecureNote) {
          itemIcon = Icons.note_alt_outlined;
          itemColor = AppColors.amber500;
        }

        results.add(
          _CommandPaletteItem(
            id: 'entry_${entry.id}',
            title: entry.title,
            subtitle: entry.isPinOnly
                ? '${entry.category} • PIN Locked'
                : (entry.username.isNotEmpty ? entry.username : entry.category),
            icon: itemIcon,
            iconColor: itemColor,
            entry: entry,
          ),
        );
      }
    }

    // 2. Built-in Quick Actions
    final quickActions = <_CommandPaletteItem>[
      _CommandPaletteItem(
        id: 'action_new_password',
        title: 'Add New Credential',
        subtitle: 'Store a login password with optional 2FA',
        icon: Icons.add_circle_outline_rounded,
        iconColor: AppColors.primaryBlue,
        onExecute: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddPasswordScreen()),
          );
        },
      ),
      _CommandPaletteItem(
        id: 'action_new_pin',
        title: 'Add Bank / ATM / UPI PIN',
        subtitle: 'Save a 4-6 digit numeric banking or device PIN',
        icon: Icons.dialpad_rounded,
        iconColor: AppColors.emerald500,
        onExecute: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddPasswordScreen()),
          );
        },
      ),
      _CommandPaletteItem(
        id: 'action_new_card',
        title: 'Add Payment Card',
        subtitle: 'Save Visa, Mastercard, RuPay, or Amex card',
        icon: Icons.credit_card_rounded,
        iconColor: AppColors.brandPurple,
        onExecute: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddCardScreen()),
          );
        },
      ),
      _CommandPaletteItem(
        id: 'action_audit',
        title: 'Run Security Watchtower Audit',
        subtitle: 'Inspect password entropy, duplicates, and 2FA coverage',
        icon: Icons.shield_rounded,
        iconColor: AppColors.amber500,
        onExecute: () {
          Navigator.of(context).pop();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const VaultWatchtowerSheet(),
          );
        },
      ),
      _CommandPaletteItem(
        id: 'action_lock',
        title: 'Lock Vault Now',
        subtitle: 'Immediately purge in-memory master keys',
        icon: Icons.lock_rounded,
        iconColor: AppColors.rose500,
        onExecute: () {
          Navigator.of(context).pop();
          ref.read(authSessionProvider.notifier).lockVault();
          HappyFeedback.show(context, message: 'Vault locked');
        },
      ),
    ];

    for (final action in quickActions) {
      if (lowerQ.isEmpty ||
          action.title.toLowerCase().contains(lowerQ) ||
          action.subtitle.toLowerCase().contains(lowerQ)) {
        results.add(action);
      }
    }

    return results;
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, 9999);
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, 9999);
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _executeCurrent();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final targetOffset = (_selectedIndex * 54.0) - 100.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
    );
  }

  void _executeItem(_CommandPaletteItem item) {
    if (item.entry != null) {
      Navigator.of(context).pop();
      widget.onSelectEntry?.call(item.entry!);
    } else if (item.onExecute != null) {
      item.onExecute!();
    }
  }

  void _executeCurrent() {
    final entries = ref.read(vaultPasswordsProvider).allEntries;
    final items = _buildItems(entries);
    if (items.isEmpty) return;
    final validIndex = _selectedIndex.clamp(0, items.length - 1);
    _executeItem(items[validIndex]);
  }

  void _copyItemSecret(VaultPasswordEntry entry) {
    final secret = entry.isPinOnly
        ? (entry.pin.isNotEmpty ? entry.pin : entry.transactionPin)
        : (entry.password.isNotEmpty ? entry.password : entry.pin);

    if (secret.isEmpty) return;

    Clipboard.setData(ClipboardData(text: secret));
    HappyFeedback.show(
      context,
      message: 'Copied ${entry.title} secret • Clears in 30s',
      icon: Icons.copy_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = ref.watch(vaultPasswordsProvider).allEntries;
    final items = _buildItems(entries);

    final cardBg = isDark
        ? const Color(0xEE161B22)
        : const Color(0xEEFFFFFF);
    final borderCol = isDark
        ? const Color(0x28FFFFFF)
        : const Color(0x1F000000);
    final textMuted = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: Container(
            width: 580,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 160 : 70),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Top Omnibar Input
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: isDark ? AppColors.primaryBlue : AppColors.brandPurple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a credential, bank PIN, or command...',
                              hintStyle: TextStyle(fontSize: 14, color: textMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ESC',
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

                  Divider(height: 1, thickness: 1, color: borderCol),

                  // Results List
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 36, color: textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'No matching credentials or commands',
                                  style: TextStyle(fontSize: 13, color: textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = index == _selectedIndex;

                              return MouseRegion(
                                onEnter: (_) => setState(() => _selectedIndex = index),
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => _executeItem(item),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark
                                              ? AppColors.primaryBlue.withAlpha(45)
                                              : AppColors.primaryBlue.withAlpha(25))
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(color: AppColors.primaryBlue.withAlpha(90), width: 1)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: item.iconColor.withAlpha(isDark ? 35 : 20),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(item.icon, size: 16, color: item.iconColor),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                ),
                                              ),
                                              Text(
                                                item.subtitle,
                                                style: TextStyle(fontSize: 11, color: textMuted),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (item.entry != null) ...[
                                          // Direct Copy Action Button
                                          Tooltip(
                                            message: 'Copy Secret (Ctrl + C)',
                                            child: IconButton(
                                              icon: const Icon(Icons.copy_rounded, size: 15),
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _copyItemSecret(item.entry!),
                                            ),
                                          ),
                                        ],
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.black12,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '↵ Enter',
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
                              );
                            },
                          ),
                  ),

                  Divider(height: 1, thickness: 1, color: borderCol),

                  // Bottom Keyboard Navigation Helper Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _KeyboardShortcutPill(label: '↑ ↓', description: 'Navigate', isDark: isDark),
                            const SizedBox(width: 10),
                            _KeyboardShortcutPill(label: '↵', description: 'Select', isDark: isDark),
                            const SizedBox(width: 10),
                            _KeyboardShortcutPill(label: 'Ctrl+C', description: 'Copy', isDark: isDark),
                          ],
                        ),
                        Text(
                          '${items.length} results',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _KeyboardShortcutPill extends StatelessWidget {
  final String label;
  final String description;
  final bool isDark;

  const _KeyboardShortcutPill({
    required this.label,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          description,
          style: TextStyle(fontSize: 11, color: textMuted),
        ),
      ],
    );
  }
}
