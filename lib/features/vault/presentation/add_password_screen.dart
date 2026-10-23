import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/core/widgets/expressive/expressive_swipe_slider.dart';
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
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSecureNote = false;
  bool _isFavorite = false;
  String _selectedCategory = 'Google';
  bool _obscurePassword = true;

  void _openAddCategory() async {
    final newCat = await showAddCategoryDialog(context, ref);
    if (newCat != null && mounted) {
      setState(() => _selectedCategory = newCat);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
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

    final newEntry = VaultPasswordEntry(
      id: 'vault-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      username: _isSecureNote ? '' : (usernameOrEmail.isNotEmpty ? usernameOrEmail : 'User'),
      email: !_isSecureNote && usernameOrEmail.contains('@') ? usernameOrEmail : '',
      password: _isSecureNote ? '' : password,
      category: _isSecureNote ? 'Notes' : _selectedCategory,
      websiteUrl: _isSecureNote ? '' : _urlController.text.trim(),
      notes: _notesController.text.trim(),
      totpSecret: '',
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
              size: 24,
            ),
            tooltip: _isFavorite ? 'Remove from favorites' : 'Mark as favorite',
            splashRadius: 20,
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              overlayColor: AppColors.primaryBlue.withAlpha(25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Save',
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
              // Item Type Segmented Switcher
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Login / Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Secure Note', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
                selected: {_isSecureNote},
                onSelectionChanged: (set) {
                  HapticFeedback.selectionClick();
                  setState(() => _isSecureNote = set.first);
                },
              ),
              const SizedBox(height: 18),

              // Category Selector (only for Logins)
              if (!_isSecureNote) ...[
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
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
              ],

              // Merged Card: Website URL & Notes
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol, width: 1),
                ),
                child: Column(
                  children: [
                    if (!_isSecureNote) ...[
                      TextField(
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
                      Divider(height: 1, color: borderCol),
                    ],
                    TextField(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
