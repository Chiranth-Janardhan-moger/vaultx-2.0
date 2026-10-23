import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/core/widgets/character_indexer_chips.dart';
import 'package:vaultx/core/widgets/gliding_category_bar.dart';
import 'package:vaultx/features/desktop/presentation/desktop_master_detail_view.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/vault/presentation/add_password_screen.dart';
import 'package:vaultx/features/vault/presentation/edit_password_screen.dart';
import 'package:vaultx/features/vault/presentation/vault_watchtower_sheet.dart';

/// Screen 2: Passwords Vault Screen (Home)
///
/// Features instant search, category filter pills, responsive card list,
/// inspection bottom sheet with quick copy/unmask, and add action.
class PasswordsVaultScreen extends ConsumerStatefulWidget {
  const PasswordsVaultScreen({super.key});

  @override
  ConsumerState<PasswordsVaultScreen> createState() => _PasswordsVaultScreenState();
}

class _PasswordsVaultScreenState extends ConsumerState<PasswordsVaultScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openInspectionSheet(VaultPasswordEntry entry) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CredentialInspectionSheet(entry: entry),
    );
  }

  void _openWatchtowerSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VaultWatchtowerSheet(),
    );
  }

  void _navigateToAdd() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AddPasswordScreen(),
      ),
    );
  }

  void _openAddCategory() async {
    final newCat = await showAddCategoryDialog(context, ref);
    if (newCat != null && mounted) {
      ref.read(vaultPasswordsProvider.notifier).setSelectedCategory(newCat);
    }
  }

  void _showCategoryActionSheet(String category) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final catColor = getCategoryColor(category);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Material(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderCol),
            ),
            child: SafeArea(
              top: false,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: catColor.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: catColor.withAlpha(100), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.label_rounded,
                        color: catColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Category Options',
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: borderCol),
                const SizedBox(height: 8),

                // Option 1: Edit Category
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Edit Category',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Rename this category tag',
                    style: TextStyle(fontSize: 12, color: mutedCol),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _openEditCategoryDialog(category);
                  },
                ),

                // Option 2: Delete Category
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.rose500,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Delete Category',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.rose500,
                    ),
                  ),
                  subtitle: Text(
                    'Move items in this tag to Others',
                    style: TextStyle(fontSize: 12, color: mutedCol),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _confirmDeleteCategory(category);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  void _openEditCategoryDialog(String oldCategory) {
    final textController = TextEditingController(text: oldCategory);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

    void submit(BuildContext dialogCtx) {
      final newName = textController.text.trim();
      if (newName.isEmpty) return;
      if (newName.toLowerCase() != oldCategory.toLowerCase()) {
        ref.read(vaultPasswordsProvider.notifier).renameCategory(oldCategory, newName);
        HappyFeedback.show(context, message: 'Category renamed to "$newName"');
      }
      Navigator.of(dialogCtx).pop();
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderCol),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rename "$oldCategory"',
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: textController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => submit(dialogCtx),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: mutedCol,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => submit(dialogCtx),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteCategory(String category) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$category"?'),
        content: const Text(
          'Items under this category will be moved to "Others". This category tag will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rose500,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(vaultPasswordsProvider.notifier).deleteCategory(category);
              HapticFeedback.heavyImpact();
              Navigator.of(ctx).pop();
              HappyFeedback.show(context, message: 'Category "$category" deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return const DesktopMasterDetailView();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultState = ref.watch(vaultPasswordsProvider);
    final entries = vaultState.filteredEntries;
    final report = VaultWatchtowerEngine.audit(vaultState.allEntries);
    final categories = vaultState.allCategories;

    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final securityColor = report.healthScore >= 80
        ? AppColors.emerald500
        : AppColors.amber500;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: entries.isEmpty
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Passwords',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Security Health Score Shield Icon
                        Tooltip(
                          message: 'Security Health Score (${report.healthScore}%)',
                          child: GestureDetector(
                            onTap: _openWatchtowerSheet,
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: cardBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderCol),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.shield_rounded,
                                size: 20,
                                color: securityColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Add Password Button
                        IconButton.filled(
                          onPressed: _navigateToAdd,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 22),
                          tooltip: 'Add Password',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(vaultPasswordsProvider.notifier).setSearchQuery(val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search passwords & accounts...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(vaultPasswordsProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Category Filter Pills (Apple HIG & OriginOS Gliding Magnetic Bar)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: GlidingCategoryBar(
                  items: categories.map((cat) {
                    final cleanCat = cat.toLowerCase();
                    final isAll = cleanCat == 'all';
                    final isFav = cleanCat == 'favorites' || cleanCat.contains('fav');
                    final isPins = cleanCat == 'pins' || cleanCat == 'pin';
                    final isOthers = cleanCat == 'others';

                    final activeList = vaultState.activeEntries;
                    final int count;
                    if (isAll) {
                      count = activeList.length;
                    } else if (isFav) {
                      count = activeList.where((e) => e.isFavorite).length;
                    } else if (isPins) {
                      count = activeList
                          .where((e) => e.hasPin || e.isPinOnly || e.category.toLowerCase() == 'pins' || e.category.toLowerCase() == 'pin')
                          .length;
                    } else if (isOthers) {
                      count = activeList
                          .where((e) => e.category.toLowerCase() == 'others' ||
                              !VaultPasswordsState.defaultCategories.any((c) => c.toLowerCase() == e.category.toLowerCase()))
                          .length;
                    } else {
                      count = activeList
                          .where((e) => e.category.toLowerCase() == cleanCat)
                          .length;
                    }

                    return GlidingCategoryItem(
                      id: cat,
                      label: cat,
                      count: count,
                      icon: isFav ? Icons.star_rounded : null,
                      dotColor: (!isAll && !isFav) ? getCategoryColor(cat) : null,
                      onLongPress: (isAll || isFav) ? null : () => _showCategoryActionSheet(cat),
                    );
                  }).toList(),
                  selectedId: vaultState.selectedCategory,
                  onSelected: (selectedCat) {
                    ref.read(vaultPasswordsProvider.notifier).setSelectedCategory(selectedCat);
                  },
                  trailing: Semantics(
                    button: true,
                    label: 'Add Category',
                    child: GestureDetector(
                      onTap: _openAddCategory,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primaryBlue.withAlpha(140),
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: AppColors.primaryBlue),
                            SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
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

            if (entries.isNotEmpty) ...[
              // Passwords List
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  110 + MediaQuery.of(context).viewInsets.bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = entries[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openInspectionSheet(entry),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderCol, width: 1),
                              ),
                              child: Row(
                                children: [
                                  // Monogram Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withAlpha(isDark ? 35 : 22),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      entry.title.isNotEmpty
                                          ? entry.title.substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Title and Inline Username • Category
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                entry.username.isNotEmpty
                                                    ? entry.username
                                                    : (entry.email.isNotEmpty
                                                        ? entry.email
                                                        : (entry.isSecureNote
                                                            ? 'Secure Note'
                                                            : (entry.isPinOnly ? 'Security PIN' : 'No username'))),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? AppColors.darkTextMuted
                                                      : AppColors.lightTextMuted,
                                                ),
                                              ),
                                            ),
                                            if (entry.category.isNotEmpty) ...[
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                                child: Text(
                                                  '•',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.white24 : Colors.black26,
                                                  ),
                                                ),
                                              ),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 120),
                                                child: Text(
                                                  entry.category,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: getCategoryColor(entry.category),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Trailing Actions: Favorite Star Button & Chevron
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          ref.read(vaultPasswordsProvider.notifier).toggleFavorite(entry.id);
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: entry.isFavorite
                                                ? Colors.amber.withAlpha(isDark ? 35 : 25)
                                                : Colors.transparent,
                                          ),
                                          child: Icon(
                                            entry.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 20,
                                            color: entry.isFavorite
                                                ? Colors.amber
                                                : (isDark ? Colors.white38 : Colors.black38),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: isDark ? Colors.white30 : Colors.black26,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: entries.length,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (entries.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      vaultState.selectedCategory.toLowerCase() == 'favorites'
                          ? Icons.star_border_rounded
                          : Icons.search_off_rounded,
                      size: 48,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vaultState.selectedCategory.toLowerCase() == 'favorites'
                          ? 'No favorite credentials'
                          : 'No passwords found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    if (vaultState.selectedCategory.toLowerCase() == 'favorites') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tap the star on any card to pin your favorites here.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  ),
);
  }
}


/// Secure offline scrambled PIN keypad sheet.
///
/// Randomizes digit order (0-9) to defend against shoulder-surfing and smudge attacks.
class ScrambledPinKeypad extends StatefulWidget {
  final String title;
  final String pin;

  const ScrambledPinKeypad({
    super.key,
    required this.title,
    required this.pin,
  });

  @override
  State<ScrambledPinKeypad> createState() => _ScrambledPinKeypadState();
}

class _ScrambledPinKeypadState extends State<ScrambledPinKeypad> {
  late List<int> _digits;
  String _enteredPin = '';
  bool _revealInput = false;

  @override
  void initState() {
    super.initState();
    _reshuffle();
  }

  void _reshuffle() {
    final list = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    list.shuffle(Random.secure());
    setState(() => _digits = list);
  }

  void _onDigit(int digit) {
    if (_enteredPin.length >= 12) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit.toString();
    });
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _enteredPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final isAlphanumeric = RegExp(r'[^0-9]').hasMatch(widget.pin);
    final isMatch = _enteredPin.isNotEmpty && _enteredPin == widget.pin;
    final isMismatch = _enteredPin.length >= widget.pin.length && !isMatch;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(isDark ? 35 : 22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.dialpad_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.title} Keypad',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scrambled Anti-Surveillance Keypad',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mutedCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMatch
                        ? const Color(0xFF10B981)
                        : isMismatch
                            ? AppColors.rose500
                            : borderCol,
                    width: isMatch || isMismatch ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMatch
                                ? 'PIN Verified Match'
                                : isMismatch
                                    ? 'PIN Does Not Match'
                                    : 'Test PIN Verification',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isMatch
                                  ? const Color(0xFF10B981)
                                  : isMismatch
                                      ? AppColors.rose500
                                      : mutedCol,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _enteredPin.isEmpty
                                ? 'Tap scrambled digits to test'
                                : _revealInput
                                    ? _enteredPin
                                    : List.filled(_enteredPin.length, '●').join(' '),
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: _revealInput ? 3 : 2,
                              color: _enteredPin.isEmpty ? mutedCol : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_enteredPin.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          _revealInput ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18,
                        ),
                        tooltip: _revealInput ? 'Mask input' : 'Reveal input',
                        onPressed: () => setState(() => _revealInput = !_revealInput),
                      ),
                    IconButton(
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      tooltip: 'Reshuffle keypad',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _reshuffle();
                      },
                    ),
                  ],
                ),
              ),
              if (isAlphanumeric) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CharacterIndexerChips(
                    secret: widget.pin,
                    isRevealed: _revealInput,
                    label: 'Alphanumeric PIN Indexer',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) {
                    setState(() => _enteredPin = val);
                  },
                  obscureText: !_revealInput,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText: 'Type alphanumeric code to test match',
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                for (int row = 0; row < 4; row++) ...[
                  Row(
                    children: [
                      for (int col = 0; col < 3; col++) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: _buildKey(row, col, cardBg, inputBg, borderCol, mutedCol),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(int row, int col, Color cardBg, Color inputBg, Color borderCol, Color mutedCol) {
    if (row == 3 && col == 0) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: borderCol),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _onClear,
        child: Text(
          'CLR',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: mutedCol,
          ),
        ),
      );
    } else if (row == 3 && col == 2) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: borderCol),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _onBackspace,
        child: Icon(Icons.backspace_outlined, size: 20, color: mutedCol),
      );
    } else {
      final digitIndex = row == 3 && col == 1 ? 9 : row * 3 + col;
      final digit = _digits[digitIndex];
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: inputBg,
          foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderCol),
          ),
        ),
        onPressed: () => _onDigit(digit),
        child: Text(
          '$digit',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
  }
}

/// Slide-up bottom sheet inspection modal with unmask toggles and 1-tap clipboard copy
class _CredentialInspectionSheet extends ConsumerStatefulWidget {
  final VaultPasswordEntry entry;

  const _CredentialInspectionSheet({required this.entry});

  @override
  ConsumerState<_CredentialInspectionSheet> createState() => _CredentialInspectionSheetState();
}

class _CredentialInspectionSheetState extends ConsumerState<_CredentialInspectionSheet> {
  bool _revealPassword = false;
  bool _revealPin = false;
  bool _revealTransactionPin = false;
  final Set<String> _revealedCustomFieldIds = {};

  String _formatMaskedPin(String pin) {
    final count = pin.isNotEmpty ? pin.length.clamp(1, 16) : 4;
    return List.filled(count, '●').join(' ');
  }

  void _copyToClipboard(String text, String label) {
    HapticFeedback.lightImpact();
    ClipboardSecurityService.copySecure(
      context: context,
      ref: ref,
      text: text,
      label: label,
      isSensitive: label.toLowerCase().contains('password') ||
          label.toLowerCase().contains('key') ||
          label.toLowerCase().contains('secret') ||
          label.toLowerCase().contains('pin'),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final currentEntry = ref.watch(vaultPasswordsProvider).allEntries.firstWhere(
          (e) => e.id == widget.entry.id,
          orElse: () => widget.entry,
        );

    final entropy = VaultWatchtowerEngine.calculateEntropy(currentEntry.password);
    final strengthColor = entropy >= 60
        ? AppColors.emerald500
        : entropy >= 45
            ? AppColors.amber500
            : AppColors.rose500;
    final strengthLabel = entropy >= 60
        ? 'Strong (${entropy.toStringAsFixed(0)} bits)'
        : entropy >= 45
            ? 'Medium (${entropy.toStringAsFixed(0)} bits)'
            : 'Weak (${entropy.toStringAsFixed(0)} bits)';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Apple Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(isDark ? 35 : 22),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  currentEntry.title.isNotEmpty
                      ? currentEntry.title.substring(0, 1).toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentEntry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentEntry.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  currentEntry.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: currentEntry.isFavorite
                      ? Colors.amber
                      : mutedCol,
                  size: 24,
                ),
                tooltip: currentEntry.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(vaultPasswordsProvider.notifier).toggleFavorite(currentEntry.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Group 1: Login Credentials (Inset Grouped Card)
                  Container(
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Username Row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Username',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: mutedCol,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.entry.username.isNotEmpty
                                          ? widget.entry.username
                                          : 'No username',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.entry.username.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy username',
                                  onPressed: () => _copyToClipboard(widget.entry.username, 'Username'),
                                ),
                            ],
                          ),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),

                        // Password Row
                        if (currentEntry.password.isNotEmpty || !currentEntry.hasPin) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Password',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: mutedCol,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _revealPassword
                                            ? currentEntry.password
                                            : '••••••••••••••••',
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _revealPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 18,
                                  ),
                                  tooltip: _revealPassword ? 'Mask password' : 'Show password',
                                  onPressed: () {
                                    setState(() => _revealPassword = !_revealPassword);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy password',
                                  onPressed: () => _copyToClipboard(currentEntry.password, 'Password'),
                                ),
                              ],
                            ),
                          ),
                          if (_revealPassword && currentEntry.password.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: CharacterIndexerChips(
                                secret: currentEntry.password,
                                isRevealed: true,
                                label: 'Password Character Position Index',
                              ),
                            ),
                          ],

                          // Security Entropy Evaluation Row
                          if (currentEntry.password.isNotEmpty) ...[
                            Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: strengthColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Security: $strengthLabel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: strengthColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        // ATM PIN Row
                        if (currentEntry.pin.isNotEmpty) ...[
                          Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ATM / Bank PIN',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: mutedCol,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _revealPin
                                            ? currentEntry.pin
                                            : _formatMaskedPin(currentEntry.pin),
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.dialpad_rounded, size: 18),
                                  tooltip: 'Keypad',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => ScrambledPinKeypad(
                                        title: 'ATM PIN',
                                        pin: currentEntry.pin,
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    _revealPin
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 18,
                                  ),
                                  tooltip: _revealPin ? 'Mask PIN' : 'Show PIN',
                                  onPressed: () {
                                    setState(() => _revealPin = !_revealPin);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy PIN',
                                  onPressed: () => _copyToClipboard(currentEntry.pin, 'Bank PIN'),
                                ),
                              ],
                            ),
                          ),
                          if (_revealPin && currentEntry.pin.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: CharacterIndexerChips(
                                secret: currentEntry.pin,
                                isRevealed: true,
                                label: 'ATM PIN Character Position Index',
                              ),
                            ),
                          ],
                        ],

                        // UPI PIN Row
                        if (currentEntry.transactionPin.isNotEmpty) ...[
                          Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'UPI / Transaction PIN',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: mutedCol,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _revealTransactionPin
                                            ? currentEntry.transactionPin
                                            : _formatMaskedPin(currentEntry.transactionPin),
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.dialpad_rounded, size: 18),
                                  tooltip: 'Keypad',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => ScrambledPinKeypad(
                                        title: 'UPI PIN',
                                        pin: currentEntry.transactionPin,
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    _revealTransactionPin
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 18,
                                  ),
                                  tooltip: _revealTransactionPin ? 'Mask UPI PIN' : 'Show UPI PIN',
                                  onPressed: () {
                                    setState(() => _revealTransactionPin = !_revealTransactionPin);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy UPI PIN',
                                  onPressed: () => _copyToClipboard(currentEntry.transactionPin, 'UPI PIN'),
                                ),
                              ],
                            ),
                          ),
                          if (_revealTransactionPin && currentEntry.transactionPin.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: CharacterIndexerChips(
                                secret: currentEntry.transactionPin,
                                isRevealed: true,
                                label: 'UPI PIN Character Position Index',
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // Custom Secure Fields Group
                  if (currentEntry.hasCustomFields) ...[
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                const Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryBlue),
                                const SizedBox(width: 8),
                                Text(
                                  'Custom Secure Fields',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: mutedCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...List.generate(currentEntry.customFields.length, (idx) {
                            final field = currentEntry.customFields[idx];
                            final isRevealed =
                                !field.isConcealed || _revealedCustomFieldIds.contains(field.id);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              field.label,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: mutedCol,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isRevealed
                                                  ? field.value
                                                  : ('● ' * field.value.length.clamp(4, 16)).trim(),
                                              style: TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: isRevealed ? 0.5 : 2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (field.isConcealed)
                                        IconButton(
                                          icon: Icon(
                                            isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                            size: 18,
                                          ),
                                          tooltip: isRevealed ? 'Mask field' : 'Show field',
                                          onPressed: () {
                                            setState(() {
                                              if (_revealedCustomFieldIds.contains(field.id)) {
                                                _revealedCustomFieldIds.remove(field.id);
                                              } else {
                                                _revealedCustomFieldIds.add(field.id);
                                              }
                                            });
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 18),
                                        tooltip: 'Copy ${field.label}',
                                        onPressed: () => _copyToClipboard(field.value, field.label),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isRevealed && field.value.length >= 2) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                    child: CharacterIndexerChips(
                                      secret: field.value,
                                      isRevealed: true,
                                      label: '${field.label} Character Index',
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // Group 2: Details & Notes (Inset Grouped Card)
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.entry.websiteUrl.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Website URL',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: mutedCol,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.entry.websiteUrl,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy URL',
                                  onPressed: () => _copyToClipboard(widget.entry.websiteUrl, 'URL'),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),
                        ],

                        if (widget.entry.notes.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: mutedCol,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.entry.notes,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),
                        ],

                        // Timestamps Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: currentEntry.updatedAt.difference(currentEntry.createdAt).inSeconds.abs() > 1
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Created',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: mutedCol,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatDateTime(widget.entry.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 26,
                                      color: borderCol,
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Edited',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: mutedCol,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatDateTime(widget.entry.updatedAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Created',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: mutedCol,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDateTime(widget.entry.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions: 2 Columns in a Single Row (Delete & Edit)
                  Row(
                    children: [
                      // Delete Action Column
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: Material(
                            color: isDark
                                ? AppColors.rose950.withAlpha(70)
                                : AppColors.rose500.withAlpha(20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: AppColors.rose500.withAlpha(isDark ? 80 : 140),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text(
                                      'Delete Password?',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    content: Text(
                                      'This will permanently remove "${widget.entry.title}" from your vault.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.rose500,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(vaultPasswordsProvider.notifier)
                                              .deletePassword(widget.entry.id);
                                          Navigator.of(ctx).pop();
                                          Navigator.of(context).pop();
                                          HapticFeedback.heavyImpact();
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: isDark ? AppColors.rose400 : const Color(0xFFBE123C),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.rose400 : const Color(0xFFBE123C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Edit Action Column
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text(
                              'Edit',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EditPasswordScreen(entry: currentEntry),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
