import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/crypto/totp_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/expressive/expressive.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

/// Screen 3: Add Password / Secure Note Screen
///
/// Supports standard Login credentials with optional TOTP 2FA authenticator
/// and encrypted Secure Notes with category labeling and swipe password generation.
class AddPasswordScreen extends ConsumerStatefulWidget {
  const AddPasswordScreen({super.key});

  @override
  ConsumerState<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends ConsumerState<AddPasswordScreen> {
  final _titleController = TextEditingController();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSecureNote = false;
  bool _isFavorite = false;
  String _selectedCategory = 'Email';
  bool _obscurePassword = true;

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
    setState(() {
      _selectedCategory = trimmed;
    });
    HapticFeedback.mediumImpact();
    Navigator.of(dialogContext).pop();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateRandomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()_+-=[]{}|';
    final random = Random.secure();
    final generated = List.generate(18, (_) => chars[random.nextInt(chars.length)]).join();
    setState(() {
      _passwordController.text = generated;
      _obscurePassword = false;
    });
    HappyFeedback.show(
      context,
      message: 'Strong 18-character password generated!',
      icon: Icons.auto_awesome_rounded,
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    final usernameOrEmail = _usernameOrEmailController.text.trim();
    final password = _passwordController.text.trim();
    final totpRaw = _totpController.text.trim();

    if (_isSecureNote) {
      if (title.isEmpty) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.rose500,
            content: Text('Please enter a title for this secure note.'),
          ),
        );
        return;
      }
    } else {
      if (title.isEmpty || password.isEmpty) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.rose500,
            content: Text('Please enter at least a title and password.'),
          ),
        );
        return;
      }
    }

    String extractedTotp = totpRaw;
    if (totpRaw.startsWith('otpauth://')) {
      final parsed = TotpService.parseUri(totpRaw);
      if (parsed != null) {
        extractedTotp = parsed.secret;
      }
    }

    final newEntry = VaultPasswordEntry(
      id: 'vault-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      username: _isSecureNote ? '' : (usernameOrEmail.isNotEmpty ? usernameOrEmail : 'User'),
      email: !_isSecureNote && usernameOrEmail.contains('@') ? usernameOrEmail : '',
      password: _isSecureNote ? '' : password,
      category: _isSecureNote ? 'Notes' : _selectedCategory,
      websiteUrl: _isSecureNote ? '' : _urlController.text.trim(),
      notes: _notesController.text.trim(),
      totpSecret: extractedTotp,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isFavorite: _isFavorite,
    );

    ref.read(vaultPasswordsProvider.notifier).addPassword(newEntry);
    HappyFeedback.vibrate();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final categories = ref.watch(vaultPasswordsProvider).allCategories;

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Cancel',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 16,
            ),
          ),
        ),
        leadingWidth: 84,
        title: Text(
          _isSecureNote ? 'Add Secure Note' : 'Add Password',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite
                  ? Colors.amber
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              size: 22,
            ),
            tooltip: _isFavorite ? 'Remove from favorites' : 'Mark as favorite',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ExpressiveButton.filled(
              onPressed: _save,
              size: ExpressiveButtonSize.compact,
              label: 'Save',
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
              // Item Type Segmented Switcher
              ExpressiveSegmentedButton<bool>(
                items: const [false, true],
                selectedItem: _isSecureNote,
                onSelected: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _isSecureNote = val);
                },
                itemBuilder: (context, val, isSelected) {
                  final (icon, label) = val
                      ? (Icons.note_alt_outlined, 'Secure Note')
                      : (Icons.password_rounded, 'Login / Password');
                  final color = isSelected
                      ? AppColors.primaryBlue
                      : Theme.of(context).colorScheme.onSurfaceVariant;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Category Selector (only for Logins)
              if (!_isSecureNote) ...[
                Text(
                  'CHOOSE CATEGORY',
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
                      if (index == 0) {
                        return ActionChip(
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                          label: const Text('Add Category'),
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
                          onPressed: _showAddCategoryDialog,
                        );
                      }

                      final cat = categories[index - 1];
                      final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                      return ChoiceChip(
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
                const SizedBox(height: 20),
              ],

              // Credential Input Group
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol, width: 1),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: _isSecureNote ? 'Note Title' : 'Title / Service Name',
                        hintText: _isSecureNote ? 'e.g. Server SSH Key, Seed Phrase' : 'e.g. Google, GitHub, Chase',
                        prefixIcon: Icon(_isSecureNote ? Icons.description_outlined : Icons.bookmark_outline_rounded, size: 20),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    if (!_isSecureNote) ...[
                      Divider(height: 1, color: borderCol),
                      TextField(
                        controller: _usernameOrEmailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Username / Email',
                          hintText: 'e.g. alex.morgan or alex@example.com',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      Divider(height: 1, color: borderCol),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter or swipe below to generate',
                          prefixIcon: const Icon(Icons.key_rounded, size: 20),
                          suffixIcon: ExpressiveToggleIcon(
                            isToggled: !_obscurePassword,
                            firstIcon: Icons.visibility_off_rounded,
                            secondIcon: Icons.visibility_rounded,
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                            onToggle: (val) => setState(() => _obscurePassword = !val),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!_isSecureNote) ...[
                // Interactive Swipe to Create Slider
                ExpressiveSwipeSlider(
                  label: 'Swipe to Generate Password',
                  onTrigger: _generateRandomPassword,
                ),
                const SizedBox(height: 16),

                // 2FA TOTP Key input
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderCol, width: 1),
                  ),
                  child: TextField(
                    controller: _totpController,
                    decoration: const InputDecoration(
                      labelText: '2FA Authenticator Key (Optional)',
                      hintText: 'Base32 secret (e.g. JBSWY3D...) or otpauth:// URI',
                      prefixIcon: Icon(Icons.security_rounded, size: 20, color: AppColors.primaryBlue),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Website URL
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderCol, width: 1),
                  ),
                  child: TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Website URL',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.link_rounded, size: 20),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notes Input (Expanded for Secure Notes)
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol, width: 1),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: _isSecureNote ? 10 : 3,
                  decoration: InputDecoration(
                    labelText: _isSecureNote ? 'Encrypted Secure Note Content' : 'Notes',
                    hintText: _isSecureNote
                        ? 'Write secret keys, seed phrases, recovery backup codes, or confidential documents...'
                        : 'Additional secure notes or recovery codes...',
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
