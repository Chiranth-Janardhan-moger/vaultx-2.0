import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/expressive/expressive.dart';
import 'package:vaultx/core/widgets/totp_code_widget.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/vault/presentation/add_password_screen.dart';
import 'package:vaultx/features/vault/presentation/edit_password_screen.dart';

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
    final categories = ['All', ...vaultState.allCategories];

    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                    ExpressiveIconButton.filled(
                      onPressed: _navigateToAdd,
                      icon: const Icon(Icons.add_rounded, size: 22),
                      tooltip: 'Add Password',
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
                    hintText: 'Search passwords...',
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
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Category Filter Pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
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
                            borderRadius: BorderRadius.circular(20),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryBlue : cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBlue : borderCol,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            ),
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
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openInspectionSheet(entry),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: borderCol, width: 1),
                              ),
                              child: Row(
                                children: [
                                  // Monogram Avatar
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withAlpha(25),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      entry.title.isNotEmpty
                                          ? entry.title.substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Title and Username
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
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          entry.username,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                   // Category Pill, Timestamp & Disclosure Chevron
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (entry.hasTotp) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBlue.withAlpha(isDark ? 45 : 30),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                '2FA',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primaryBlue,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: inputBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              entry.category,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? AppColors.darkTextMuted
                                                    : AppColors.lightTextMuted,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatUpdatedAt(entry.updatedAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted,
                                        ),
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
                      Icons.search_off_rounded,
                      size: 48,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No passwords found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
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
class _CredentialInspectionSheet extends StatefulWidget {
  final VaultPasswordEntry entry;

  const _CredentialInspectionSheet({required this.entry});

  @override
  State<_CredentialInspectionSheet> createState() => _CredentialInspectionSheetState();
}

class _CredentialInspectionSheetState extends State<_CredentialInspectionSheet> {
  bool _revealPassword = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HappyFeedback.show(
      context,
      message: '$label copied to clipboard',
      icon: Icons.copy_rounded,
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

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
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
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.entry.title.isNotEmpty
                      ? widget.entry.title.substring(0, 1).toUpperCase()
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
                      widget.entry.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.entry.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, size: 20),
                tooltip: 'Credential Info',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditPasswordScreen(entry: widget.entry),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Real-time 2FA TOTP Authenticator Card
          if (widget.entry.hasTotp) ...[
            TotpCodeWidget(
              secret: widget.entry.totpSecret,
              accountLabel: widget.entry.username.isNotEmpty ? widget.entry.username : widget.entry.title,
            ),
            const SizedBox(height: 14),
          ],

          // Username Tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
            ),
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
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      Text(
                        widget.entry.username,
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
                  tooltip: 'Copy username',
                  onPressed: () => _copyToClipboard(widget.entry.username, 'Username'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Password Tile with Reveal Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
            ),
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
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      Text(
                        _revealPassword
                            ? widget.entry.password
                            : '••••••••••••••••',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 14,
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
          const SizedBox(height: 16),

          // Website URL Tile (shown only if provided)
          if (widget.entry.websiteUrl.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(14),
              ),
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
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
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
            const SizedBox(height: 10),
          ],

          // Notes Tile (shown only if provided)
          if (widget.entry.notes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
            const SizedBox(height: 10),
          ],

          // Timestamps Section: Created & Edited Date & Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
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
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
                  height: 28,
                  color: borderCol,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
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
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
            ),
          ),
          const SizedBox(height: 16),

          // Delete Password Button
          Consumer(
            builder: (context, ref, _) {
              return Material(
                color: isDark
                    ? AppColors.rose950.withAlpha(80)
                    : AppColors.rose500.withAlpha(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.rose500.withAlpha(isDark ? 80 : 160),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: isDark ? AppColors.rose400 : const Color(0xFFBE123C),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Password',
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
              );
            },
          ),
        ],
      ),
    );
  }
}
