import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/expressive/expressive.dart';
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

  void _showAddCategoryDialog() {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'New Category',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Category Name',
              hintText: 'e.g. Work, Gaming, Crypto',
              filled: true,
              fillColor: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (val) => _submitNewCategory(val, ctx),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _submitNewCategory(textController.text, ctx),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _submitNewCategory(String name, BuildContext dialogContext) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    ref.read(vaultPasswordsProvider.notifier).addCategory(trimmed);
    ref.read(vaultPasswordsProvider.notifier).setSelectedCategory(trimmed);
    HapticFeedback.mediumImpact();
    Navigator.of(dialogContext).pop();
  }

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

  /// Returns a compact "27 Sep, 2:43 PM" style label for the last-edited time.
  String _formatUpdatedAt(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    if (date == today) return 'Today, $time';
    if (date == yesterday) return 'Yesterday, $time';

    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultState = ref.watch(vaultPasswordsProvider);
    final entries = vaultState.filteredEntries;
    final report = VaultWatchtowerEngine.audit(vaultState.allEntries);
    final categories = ['All', 'Favorites', ...vaultState.allCategories];

    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final securityColor = report.healthScore < 50
        ? AppColors.rose500
        : report.healthScore < 80
            ? AppColors.amber500
            : AppColors.emerald500;

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
                        // Compact Sort Menu
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderCol),
                          ),
                          child: PopupMenuButton<VaultSortOption>(
                            tooltip: 'Sort Options',
                            icon: Icon(
                              Icons.swap_vert_rounded,
                              size: 20,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: borderCol),
                            ),
                            color: cardBg,
                            onSelected: (option) {
                              HapticFeedback.selectionClick();
                              ref.read(vaultPasswordsProvider.notifier).setSortOption(option);
                            },
                            itemBuilder: (context) {
                              return VaultSortOption.values.map((option) {
                                final isSelected = vaultState.activeSortOption == option;
                                return PopupMenuItem<VaultSortOption>(
                                  value: option,
                                  child: Row(
                                    children: [
                                      Icon(
                                        option.icon,
                                        size: 18,
                                        color: isSelected ? AppColors.primaryBlue : mutedCol,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          option.label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected
                                                ? AppColors.primaryBlue
                                                : (isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: AppColors.primaryBlue,
                                        ),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Add Password Button
                        ExpressiveIconButton.filled(
                          onPressed: _navigateToAdd,
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

            // Apple-Style Inset Security Health Banner
            if (report.totalCredentials > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openWatchtowerSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: securityColor.withAlpha(isDark ? 28 : 18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: securityColor.withAlpha(isDark ? 80 : 50),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: securityColor.withAlpha(isDark ? 50 : 35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                report.hasIssues ? Icons.shield_rounded : Icons.verified_user_rounded,
                                size: 20,
                                color: securityColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        report.hasIssues
                                            ? 'Security Recommendations'
                                            : 'Vault Security Optimal',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: securityColor,
                                        ),
                                      ),
                                      if (report.hasIssues) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: securityColor.withAlpha(isDark ? 55 : 35),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${report.totalIssues} ${report.totalIssues == 1 ? 'issue' : 'issues'}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: securityColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    report.hasIssues
                                        ? '${report.healthScore}% Health Score • Tap to inspect and fix'
                                        : '100% Health Score • Zero vulnerabilities detected',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: securityColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Category Filter Pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == categories.length) {
                      return GestureDetector(
                        onTap: _showAddCategoryDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryBlue.withAlpha(140),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
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
                      );
                    }

                    final cat = categories[index];
                    final isSelected = vaultState.selectedCategory.toLowerCase() == cat.toLowerCase();
                    final isFav = cat.toLowerCase() == 'favorites';

                    return Semantics(
                      button: true,
                      selected: isSelected,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(vaultPasswordsProvider.notifier).setSelectedCategory(cat);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryBlue : cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBlue : borderCol,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFav) ...[
                                Icon(
                                  Icons.star_rounded,
                                  size: 15,
                                  color: isSelected ? Colors.white : Colors.amber,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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

                                  // Title, Username, and Inline Metadata
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
                                        const SizedBox(height: 2),
                                        Text(
                                          entry.username.isNotEmpty
                                              ? entry.username
                                              : (entry.email.isNotEmpty
                                                  ? entry.email
                                                  : (entry.isSecureNote ? 'Secure Note' : 'No username')),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                entry.category,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? AppColors.darkTextMuted
                                                      : AppColors.lightTextMuted,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '•',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.white24 : Colors.black26,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatUpdatedAt(entry.updatedAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppColors.darkTextMuted.withAlpha(180)
                                                    : AppColors.lightTextMuted.withAlpha(180),
                                              ),
                                            ),
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

/// Slide-up bottom sheet inspection modal with unmask toggles and 1-tap clipboard copy
class _CredentialInspectionSheet extends ConsumerStatefulWidget {
  final VaultPasswordEntry entry;

  const _CredentialInspectionSheet({required this.entry});

  @override
  ConsumerState<_CredentialInspectionSheet> createState() => _CredentialInspectionSheetState();
}

class _CredentialInspectionSheetState extends ConsumerState<_CredentialInspectionSheet> {
  bool _revealPassword = false;

  void _copyToClipboard(String text, String label) {
    HapticFeedback.lightImpact();
    ClipboardSecurityService.copySecure(
      context: context,
      ref: ref,
      text: text,
      label: label,
      isSensitive: label.toLowerCase().contains('password') ||
          label.toLowerCase().contains('key') ||
          label.toLowerCase().contains('secret'),
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
                                          ? widget.entry.password
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
                                onPressed: () => _copyToClipboard(widget.entry.password, 'Password'),
                              ),
                            ],
                          ),
                        ),

                        // Security Entropy Evaluation Row
                        if (widget.entry.password.isNotEmpty) ...[
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
                    ),
                  ),

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
