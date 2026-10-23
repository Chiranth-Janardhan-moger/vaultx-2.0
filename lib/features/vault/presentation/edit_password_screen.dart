import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

/// Edit Password / Secure Note Screen
///
/// Dedicated interactive edit screen for modifying credentials,
/// 2FA TOTP secret keys, website URLs, and secure notes.
class EditPasswordScreen extends ConsumerStatefulWidget {
  final VaultPasswordEntry entry;

  const EditPasswordScreen({super.key, required this.entry});

  @override
  ConsumerState<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends ConsumerState<EditPasswordScreen> {
  bool _revealPassword = false;

  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _websiteController;
  late TextEditingController _notesController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _usernameController = TextEditingController(text: widget.entry.username);
    _passwordController = TextEditingController(text: widget.entry.password);
    _websiteController = TextEditingController(text: widget.entry.websiteUrl);
    _notesController = TextEditingController(text: widget.entry.notes);
    _selectedCategory = widget.entry.category;
  }

  void _openAddCategory() async {
    final newCat = await showAddCategoryDialog(context, ref);
    if (newCat != null && mounted) {
      setState(() => _selectedCategory = newCat);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    final updated = widget.entry.copyWith(
      title: newTitle,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      category: widget.entry.isSecureNote ? 'Notes' : _selectedCategory,
      totpSecret: widget.entry.totpSecret,
      websiteUrl: _websiteController.text.trim(),
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );

    ref.read(vaultPasswordsProvider.notifier).updatePassword(updated);
    HappyFeedback.show(
      context,
      message: widget.entry.isSecureNote
          ? 'Secure note updated successfully'
          : 'Credential updated successfully',
    );
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.entry.isSecureNote ? 'Delete Secure Note?' : 'Delete Password?'),
        content: Text(
          'Are you sure you want to delete "${widget.entry.title}"? This action cannot be undone.',
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
              ref.read(vaultPasswordsProvider.notifier).deletePassword(widget.entry.id);
              HapticFeedback.heavyImpact();
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final isNote = widget.entry.isSecureNote;
    final currentEntry = ref.watch(vaultPasswordsProvider).allEntries.firstWhere(
          (e) => e.id == widget.entry.id,
          orElse: () => widget.entry,
        );
    final categories = [
      for (final c in ref.watch(vaultPasswordsProvider).allCategories)
        if (c.toLowerCase() != 'all') c
    ];

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            overlayColor: AppColors.primaryBlue.withAlpha(25),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Cancel',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        leadingWidth: 84,
        title: Text(
          isNote ? 'Edit Secure Note' : 'Edit Credential',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              currentEntry.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: currentEntry.isFavorite ? Colors.amber : mutedCol,
              size: 22,
            ),
            tooltip: currentEntry.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            splashRadius: 20,
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(vaultPasswordsProvider.notifier).toggleFavorite(currentEntry.id);
            },
          ),
          TextButton(
            onPressed: _saveAndClose,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              overlayColor: AppColors.primaryBlue.withAlpha(25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Done',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Monogram Avatar & Editable Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF33383E) : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: borderCol, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: isNote
                          ? const Icon(Icons.note_alt_rounded, size: 36, color: AppColors.primaryBlue)
                          : Text(
                              _titleController.text.isNotEmpty
                                  ? _titleController.text.substring(0, 1).toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _titleController,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: isNote ? 'Note Title' : 'Service Name',
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          filled: true,
                          fillColor: inputBg,
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
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Credentials Group
              if (!isNote) ...[
                Text(
                  'CREDENTIALS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      // Username Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'Username',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  hintText: 'user@example.com',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: borderCol),

                      // Password Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'Password',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _passwordController,
                                obscureText: !_revealPassword,
                                decoration: const InputDecoration(
                                  hintText: 'Password',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
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
                              onPressed: () => setState(() => _revealPassword = !_revealPassword),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Category Selector (only for Logins)
              if (!isNote) ...[
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == categories.length) {
                        return ActionChip(
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          label: const Text('+ Add'),
                          backgroundColor: cardBg,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: AppColors.primaryBlue.withAlpha(140),
                              width: 1.2,
                            ),
                          ),
                          onPressed: _openAddCategory,
                        );
                      }

                      final cat = categories[index];
                      final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                      final catColor = getCategoryColor(cat);
                      return ChoiceChip(
                        avatar: isSelected
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: cardBg,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryBlue : borderCol,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Details Group
              Text(
                isNote ? 'CONTENT' : 'DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  children: [
                    if (!isNote) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'Website',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _websiteController,
                                decoration: const InputDecoration(
                                  hintText: 'https://example.com',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: borderCol),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 85,
                            child: Text(
                              isNote ? 'Content' : 'Notes',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _notesController,
                              maxLines: isNote ? 12 : 4,
                              decoration: InputDecoration(
                                hintText: isNote ? 'Write confidential notes...' : 'Additional notes...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Delete Button
              Center(
                child: TextButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_forever_rounded, color: AppColors.rose500, size: 20),
                  label: Text(
                    isNote ? 'Delete Secure Note' : 'Delete Credential',
                    style: const TextStyle(
                      color: AppColors.rose500,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
