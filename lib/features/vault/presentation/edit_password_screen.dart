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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _usernameController = TextEditingController(text: widget.entry.username);
    _passwordController = TextEditingController(text: widget.entry.password);
    _websiteController = TextEditingController(text: widget.entry.websiteUrl);
    _notesController = TextEditingController(text: widget.entry.notes);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNote ? 'Edit Secure Note' : 'Edit Credential',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderCol),
            ),
            child: const Icon(Icons.close_rounded, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              currentEntry.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: currentEntry.isFavorite ? Colors.amber : mutedCol,
              size: 22,
            ),
            tooltip: currentEntry.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(vaultPasswordsProvider.notifier).toggleFavorite(currentEntry.id);
            },
          ),
          TextButton(
            onPressed: _saveAndClose,
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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

              // Security & Protection Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.emerald950.withAlpha(120)
                      : AppColors.emerald500.withAlpha(24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.emerald500.withAlpha(isDark ? 160 : 180),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: AppColors.emerald400,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Safe & Secure',
                            style: TextStyle(
                              color: AppColors.emerald400,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Protected with zero-knowledge AES-256-GCM encryption.',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Details Group
              Text(
                isNote ? 'SECURE NOTE CONTENT' : 'ADDITIONAL DETAILS',
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
