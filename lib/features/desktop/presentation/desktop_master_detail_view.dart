import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/core/widgets/gliding_category_bar.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/desktop/presentation/command_palette_dialog.dart';
import 'package:vaultx/features/desktop/presentation/widgets/desktop_credential_detail_pane.dart';
import 'package:vaultx/features/desktop/presentation/widgets/desktop_title_bar.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/add_password_screen.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

/// Full-fidelity Windows Master-Detail view for desktop viewports (> 768px).
///
/// Features:
/// - Windows 11 Acrylic Titlebar with integrated 100% Local Vault status and Omnibar trigger.
/// - Master left navigation rail (350px) with [GlidingCategoryBar] and keyboard navigation (↑ / ↓).
/// - High-performance inline detail pane with live RFC 6238 TOTP ring and scrambled keypad.
/// - Global desktop keyboard shortcuts:
///   - `Ctrl + K`: Command Palette / Omnibar
///   - `Ctrl + L`: Instant Zero-Knowledge Vault Lock
///   - `Ctrl + N`: New Credential
///   - `Ctrl + C`: Instant Password Copy for selected item
class DesktopMasterDetailView extends ConsumerStatefulWidget {
  const DesktopMasterDetailView({super.key});

  @override
  ConsumerState<DesktopMasterDetailView> createState() =>
      _DesktopMasterDetailViewState();
}

class _DesktopMasterDetailViewState
    extends ConsumerState<DesktopMasterDetailView> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  String? _selectedEntryId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openCommandPalette() {
    CommandPaletteDialog.show(
      context,
      onSelectEntry: (entry) {
        setState(() => _selectedEntryId = entry.id);
      },
    );
  }

  void _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isControl = HardwareKeyboard.instance.isControlPressed;

    if (isControl && event.logicalKey == LogicalKeyboardKey.keyK) {
      _openCommandPalette();
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyL) {
      ref.read(authSessionProvider.notifier).lockVault();
      HappyFeedback.show(context, message: 'Vault locked');
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyN) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AddPasswordScreen()),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _navigateItems(event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1);
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyC) {
      _copySelectedSecret();
    }
  }

  void _navigateItems(int delta) {
    final filtered = _getFilteredEntries();
    if (filtered.isEmpty) return;

    final currentIndex =
        filtered.indexWhere((e) => e.id == _selectedEntryId);
    int nextIndex = 0;
    if (currentIndex != -1) {
      nextIndex = (currentIndex + delta).clamp(0, filtered.length - 1);
    }
    setState(() {
      _selectedEntryId = filtered[nextIndex].id;
    });
  }

  void _copySelectedSecret() {
    final filtered = _getFilteredEntries();
    final entry = filtered.firstWhere(
      (e) => e.id == _selectedEntryId,
      orElse: () => filtered.first,
    );

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

  List<VaultPasswordEntry> _getFilteredEntries() {
    final vaultState = ref.watch(vaultPasswordsProvider);
    var list = vaultState.filteredEntries;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.username.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultState = ref.watch(vaultPasswordsProvider);
    final filteredEntries = _getFilteredEntries();

    final borderCol = isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000);
    final masterBg = isDark ? const Color(0xFF10141B) : const Color(0xFFF1F5F9);
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    // Resolve currently selected entry
    VaultPasswordEntry? selectedEntry;
    if (_selectedEntryId != null) {
      for (final e in filteredEntries) {
        if (e.id == _selectedEntryId) {
          selectedEntry = e;
          break;
        }
      }
    }
    if (selectedEntry == null && filteredEntries.isNotEmpty) {
      selectedEntry = filteredEntries.first;
      _selectedEntryId = selectedEntry.id;
    }

    // Build category pill items for GlidingCategoryBar
    final categories = vaultState.allCategories;
    final categoryCounts = <String, int>{
      'All': vaultState.allEntries.where((e) => !e.isDeleted).length,
      '★ Favorites':
          vaultState.allEntries.where((e) => !e.isDeleted && e.isFavorite).length,
    };
    for (final String cat in categories) {
      if (cat == 'All' || cat == '★ Favorites') continue;
      categoryCounts[cat] = vaultState.allEntries
          .where((e) => !e.isDeleted && e.category.toLowerCase() == cat.toLowerCase())
          .length;
    }

    final categoryItems = categories.map((String cat) {
      final count = categoryCounts[cat] ?? 0;
      return GlidingCategoryItem(
        id: cat,
        label: cat,
        count: count > 0 ? count : null,
        dotColor: (cat != 'All' && cat != '★ Favorites')
            ? getCategoryColor(cat)
            : null,
        onLongPress: isSystemCategoryTag(cat)
            ? null
            : () => showTagActionSheet(context, ref, cat),
      );
    }).toList();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleGlobalKey,
      child: Scaffold(
        body: Column(
          children: [
            // 1. Windows Acrylic Titlebar with Omnibar & Window Controls
            DesktopTitleBar(
              onOpenCommandPalette: _openCommandPalette,
            ),

            // 2. Master-Detail Split Canvas
            Expanded(
              child: Row(
                children: [
                  // Left Master Column (350px)
                  Container(
                    width: 350,
                    decoration: BoxDecoration(
                      color: masterBg,
                      border: Border(right: BorderSide(color: borderCol, width: 1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E222A) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 16, color: textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Filter items...',
                                      hintStyle: TextStyle(fontSize: 12, color: textMuted),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => _searchController.clear(),
                                    child: Icon(Icons.close_rounded, size: 14, color: textMuted),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Gliding Category Bar
                        GlidingCategoryBar(
                          items: categoryItems,
                          selectedId: vaultState.selectedCategory,
                          onSelected: (catId) {
                            ref
                                .read(vaultPasswordsProvider.notifier)
                                .setSelectedCategory(catId);
                          },
                        ),

                        Divider(height: 1, color: borderCol),

                        // Master Entries List
                        Expanded(
                          child: filteredEntries.isEmpty
                              ? Center(
                                  child: Text(
                                    'No credentials found',
                                    style: TextStyle(fontSize: 12, color: textMuted),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredEntries.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredEntries[index];
                                    final isSelected = item.id == _selectedEntryId;
                                    final catCol = getCategoryColor(item.category);

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedEntryId = item.id);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (isDark
                                                    ? AppColors.primaryBlue.withAlpha(40)
                                                    : AppColors.primaryBlue.withAlpha(20))
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: isSelected
                                                ? Border.all(
                                                    color: AppColors.primaryBlue.withAlpha(90),
                                                    width: 1,
                                                  )
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              // Category Monogram Dot
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: catCol.withAlpha(isDark ? 35 : 20),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  item.isPinOnly || item.hasPin
                                                      ? Icons.dialpad_rounded
                                                      : (item.isSecureNote
                                                          ? Icons.note_alt_outlined
                                                          : Icons.lock_outline_rounded),
                                                  size: 14,
                                                  color: catCol,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: isSelected
                                                            ? FontWeight.w700
                                                            : FontWeight.w600,
                                                        color: isDark
                                                            ? AppColors.darkTextPrimary
                                                            : AppColors.lightTextPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      item.isPinOnly
                                                          ? 'PIN Protected'
                                                          : (item.username.isNotEmpty
                                                              ? item.username
                                                              : item.category),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: textMuted,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (item.isFavorite)
                                                const Icon(
                                                  Icons.star_rounded,
                                                  size: 15,
                                                  color: AppColors.amber500,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        Divider(height: 1, color: borderCol),

                        // Master Bottom Status Bar with Quick Actions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                '${filteredEntries.length} items',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                              const Spacer(),
                              // Quick Add Password Action
                              Tooltip(
                                message: 'New Credential (Ctrl + N)',
                                child: IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const AddPasswordScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Detail Pane (Expanded)
                  Expanded(
                    child: DesktopCredentialDetailPane(
                      entry: selectedEntry,
                      onEntryDeleted: () {
                        setState(() => _selectedEntryId = null);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
