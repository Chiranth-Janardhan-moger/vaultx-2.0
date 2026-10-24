import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/core/widgets/expressive/expressive_swipe_slider.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

class _CustomFieldFormItem {
  final String id;
  final TextEditingController labelController;
  final TextEditingController valueController;
  bool isConcealed;

  _CustomFieldFormItem({
    required this.id,
    required this.labelController,
    required this.valueController,
    this.isConcealed = true,
  });

  void dispose() {
    labelController.dispose();
    valueController.dispose();
  }
}

/// Screen 3: Add Password / Secure Note Screen
///
/// Supports standard Login credentials with optional TOTP 2FA authenticator,
/// alphanumeric PINs (e.g. cUdXa), banking custom secure fields (Customer ID,
/// Debit Card Grid, Memorable Word), and encrypted Secure Notes.
class AddPasswordScreen extends ConsumerStatefulWidget {
  const AddPasswordScreen({super.key});

  @override
  ConsumerState<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends ConsumerState<AddPasswordScreen> {
  final _titleController = TextEditingController();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _transactionPinController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_CustomFieldFormItem> _customFields = [];

  bool _isSecureNote = false;
  bool _isFavorite = false;
  String _selectedCategory = 'Google';
  bool _obscurePassword = true;
  bool _obscurePin = true;
  bool _obscureTransactionPin = true;

  void _openAddCategory() async {
    final newCat = await showAddCategoryDialog(context, ref);
    if (newCat != null && mounted) {
      setState(() => _selectedCategory = newCat);
    }
  }

  void _addCustomField([String label = '', String value = '', bool isConcealed = true]) {
    HapticFeedback.selectionClick();
    setState(() {
      _customFields.add(_CustomFieldFormItem(
        id: 'field-${DateTime.now().microsecondsSinceEpoch}-${_customFields.length}',
        labelController: TextEditingController(text: label),
        valueController: TextEditingController(text: value),
        isConcealed: isConcealed,
      ));
    });
  }

  void _removeCustomField(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      final item = _customFields.removeAt(index);
      item.dispose();
    });
  }

  void _moveCustomFieldUp(int index) {
    if (index <= 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      final item = _customFields.removeAt(index);
      _customFields.insert(index - 1, item);
    });
  }

  void _moveCustomFieldDown(int index) {
    if (index >= _customFields.length - 1) return;
    HapticFeedback.selectionClick();
    setState(() {
      final item = _customFields.removeAt(index);
      _customFields.insert(index + 1, item);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _transactionPinController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    for (final field in _customFields) {
      field.dispose();
    }
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
    final pin = _pinController.text.trim();
    final transactionPin = _transactionPinController.text.trim();

    final validCustomFields = _customFields
        .where((f) =>
            f.labelController.text.trim().isNotEmpty &&
            f.valueController.text.trim().isNotEmpty)
        .map((f) => VaultCustomField(
              id: f.id,
              label: f.labelController.text.trim(),
              value: f.valueController.text.trim(),
              isConcealed: f.isConcealed,
            ))
        .toList();

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
      if (title.isEmpty ||
          (password.isEmpty &&
              pin.isEmpty &&
              transactionPin.isEmpty &&
              validCustomFields.isEmpty)) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.rose500,
            content: Text('Please enter at least a title and a password, PIN, or custom field.'),
          ),
        );
        return;
      }
    }

    final newEntry = VaultPasswordEntry(
      id: 'vault-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      username: _isSecureNote
          ? ''
          : (usernameOrEmail.isNotEmpty
              ? usernameOrEmail
              : (pin.isNotEmpty || transactionPin.isNotEmpty || validCustomFields.isNotEmpty
                  ? ''
                  : 'User')),
      email: !_isSecureNote && usernameOrEmail.contains('@') ? usernameOrEmail : '',
      password: _isSecureNote ? '' : password,
      pin: _isSecureNote ? '' : pin,
      transactionPin: _isSecureNote ? '' : transactionPin,
      customFields: _isSecureNote ? const [] : validCustomFields,
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
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final categories = [
      for (final c in ref.watch(vaultPasswordsProvider).allCategories)
        if (c.toLowerCase() != 'all') c
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _isSecureNote ? 'New Secure Note' : 'Add Credential',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? AppColors.amber500 : null,
            ),
            tooltip: _isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                backgroundColor: AppColors.primaryBlue.withAlpha(isDark ? 35 : 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entry Type Segmented Switch: Credential vs Secure Note
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol, width: 1),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isSecureNote = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isSecureNote ? AppColors.primaryBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: !_isSecureNote ? Colors.white : textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Login & PIN',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: !_isSecureNote ? Colors.white : textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isSecureNote = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isSecureNote ? AppColors.primaryBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: _isSecureNote ? Colors.white : textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Secure Note',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _isSecureNote ? Colors.white : textMuted,
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
              const SizedBox(height: 16),

              // Category Selector
              if (!_isSecureNote) ...[
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      if (i == categories.length) {
                        return ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('+ Add'),
                          onPressed: _openAddCategory,
                          backgroundColor: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: borderCol),
                          ),
                        );
                      }
                      final cat = categories[i];
                      final isSelected = cat == _selectedCategory;
                      return GestureDetector(
                        onLongPress: isSystemCategoryTag(cat)
                            ? null
                            : () {
                                showTagActionSheet(
                                  context,
                                  ref,
                                  cat,
                                  onRenamed: (newName) {
                                    if (mounted) {
                                      setState(() => _selectedCategory = newName);
                                    }
                                  },
                                  onDeleted: () {
                                    if (mounted &&
                                        _selectedCategory.toLowerCase() == cat.toLowerCase()) {
                                      setState(() => _selectedCategory = 'Google');
                                    }
                                  },
                                );
                              },
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            }
                          },
                          selectedColor: AppColors.primaryBlue.withAlpha(isDark ? 45 : 30),
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryBlue : borderCol,
                            ),
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
                      Divider(height: 1, color: borderCol),
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.text,
                        obscureText: _obscurePin,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Bank / ATM PIN',
                          hintText: 'e.g. 4-6 digits or alphanumeric code (cUdXa)',
                          prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
                            onPressed: () => setState(() => _obscurePin = !_obscurePin),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      Divider(height: 1, color: borderCol),
                      TextField(
                        controller: _transactionPinController,
                        keyboardType: TextInputType.text,
                        obscureText: _obscureTransactionPin,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'UPI / Transaction PIN',
                          hintText: 'e.g. 4-6 digit UPI PIN or secret token',
                          prefixIcon: const Icon(Icons.dialpad_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureTransactionPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            tooltip: _obscureTransactionPin ? 'Show UPI PIN' : 'Hide UPI PIN',
                            onPressed: () => setState(() => _obscureTransactionPin = !_obscureTransactionPin),
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
                const SizedBox(height: 20),

                // Custom Secure Fields Section (Banking, Memorable Words, Grid Codes)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CUSTOM SECURE FIELDS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: textMuted,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addCustomField(),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Field', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Preset Quick-Add Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.pin_outlined, size: 14),
                        label: const Text('Custom PIN', style: TextStyle(fontSize: 11)),
                        backgroundColor: cardBg,
                        onPressed: () => _addCustomField('Custom PIN', '', true),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderCol)),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.badge_outlined, size: 14),
                        label: const Text('Customer ID', style: TextStyle(fontSize: 11)),
                        backgroundColor: cardBg,
                        onPressed: () => _addCustomField('Customer ID', '', false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderCol)),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.spellcheck_rounded, size: 14),
                        label: const Text('Memorable Word', style: TextStyle(fontSize: 11)),
                        backgroundColor: cardBg,
                        onPressed: () => _addCustomField('Memorable Word', '', true),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderCol)),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.grid_4x4_rounded, size: 14),
                        label: const Text('Card Grid (A-P)', style: TextStyle(fontSize: 11)),
                        backgroundColor: cardBg,
                        onPressed: () => _addCustomField('Card Grid (A-P)', '', true),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderCol)),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.help_outline_rounded, size: 14),
                        label: const Text('Security Answer', style: TextStyle(fontSize: 11)),
                        backgroundColor: cardBg,
                        onPressed: () => _addCustomField('Security Answer', '', true),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderCol)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Custom Fields List
                if (_customFields.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderCol, width: 1),
                    ),
                    child: Column(
                      children: List.generate(_customFields.length, (index) {
                        final field = _customFields[index];
                        final isFirst = index == 0;
                        final isLast = index == _customFields.length - 1;

                        return Column(
                          children: [
                            if (!isFirst) Divider(height: 1, color: borderCol),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Reorder buttons, Label input, and Delete Trash Icon
                                  Row(
                                    children: [
                                      // Reorder buttons pill
                                      Container(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withAlpha(10)
                                              : Colors.black.withAlpha(8),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: isFirst ? null : () => _moveCustomFieldUp(index),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                child: Icon(
                                                  Icons.keyboard_arrow_up_rounded,
                                                  size: 18,
                                                  color: isFirst ? borderCol : textMuted,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 12,
                                              color: borderCol,
                                            ),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: isLast ? null : () => _moveCustomFieldDown(index),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                child: Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  size: 18,
                                                  color: isLast ? borderCol : textMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Field Label Input
                                      Expanded(
                                        child: TextField(
                                          controller: field.labelController,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            hintText: 'Field label',
                                            hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: textMuted,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                          ),
                                        ),
                                      ),

                                      // Delete Button: Real Delete Trash Icon
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: AppColors.rose500,
                                        ),
                                        tooltip: 'Delete field',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _removeCustomField(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Bottom Row: Value Input Box with Lock icon & Eye Toggle
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderCol, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 10, right: 6),
                                          child: Icon(
                                            field.isConcealed ? Icons.lock_outline_rounded : Icons.key_rounded,
                                            size: 16,
                                            color: textMuted,
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: field.valueController,
                                            obscureText: field.isConcealed,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'JetBrains Mono',
                                              letterSpacing: 0.5,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Secret value',
                                              hintStyle: TextStyle(
                                                fontSize: 12,
                                                color: textMuted,
                                                fontFamily: 'Inter',
                                                letterSpacing: 0,
                                              ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            field.isConcealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                            size: 18,
                                            color: textMuted,
                                          ),
                                          tooltip: field.isConcealed ? 'Masked secret' : 'Visible field',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => setState(() => field.isConcealed = !field.isConcealed),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
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
