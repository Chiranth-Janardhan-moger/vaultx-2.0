import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

class _CustomFieldEditItem {
  final String id;
  final TextEditingController labelController;
  final TextEditingController valueController;
  bool isConcealed;

  _CustomFieldEditItem({
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

/// Screen 4: Edit Password / Credential Screen
///
/// Supports editing standard credentials, alphanumeric PINs (e.g. cUdXa),
/// custom banking secure fields, categories, and secure note content.
class EditPasswordScreen extends ConsumerStatefulWidget {
  final VaultPasswordEntry entry;

  const EditPasswordScreen({
    super.key,
    required this.entry,
  });

  @override
  ConsumerState<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends ConsumerState<EditPasswordScreen> {
  bool _revealPassword = false;
  bool _revealPin = false;
  bool _revealTransactionPin = false;

  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _pinController;
  late TextEditingController _transactionPinController;
  late TextEditingController _websiteController;
  late TextEditingController _notesController;
  late String _selectedCategory;

  final List<_CustomFieldEditItem> _customFields = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _usernameController = TextEditingController(text: widget.entry.username);
    _passwordController = TextEditingController(text: widget.entry.password);
    _pinController = TextEditingController(text: widget.entry.pin);
    _transactionPinController = TextEditingController(text: widget.entry.transactionPin);
    _websiteController = TextEditingController(text: widget.entry.websiteUrl);
    _notesController = TextEditingController(text: widget.entry.notes);
    _selectedCategory = widget.entry.category;

    for (final cf in widget.entry.customFields) {
      _customFields.add(_CustomFieldEditItem(
        id: cf.id,
        labelController: TextEditingController(text: cf.label),
        valueController: TextEditingController(text: cf.value),
        isConcealed: cf.isConcealed,
      ));
    }
  }

  void _openAddCategory() async {
    final newCat = await showAddCategoryDialog(context, ref);
    if (newCat != null && mounted) {
      setState(() => _selectedCategory = newCat);
    }
  }

  void _addCustomField([String label = '', String value = '', bool isConcealed = true]) {
    HapticFeedback.selectionClick();
    setState(() {
      _customFields.add(_CustomFieldEditItem(
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
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _transactionPinController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    for (final field in _customFields) {
      field.dispose();
    }
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

    final newPassword = _passwordController.text.trim();
    final newPin = _pinController.text.trim();
    final newTransactionPin = _transactionPinController.text.trim();

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

    if (!widget.entry.isSecureNote &&
        newPassword.isEmpty &&
        newPin.isEmpty &&
        newTransactionPin.isEmpty &&
        validCustomFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password, PIN, or custom field')),
      );
      return;
    }

    final updated = widget.entry.copyWith(
      title: newTitle,
      username: _usernameController.text.trim(),
      password: newPassword,
      pin: newPin,
      transactionPin: newTransactionPin,
      customFields: validCustomFields,
      category: widget.entry.isSecureNote ? 'Notes' : _selectedCategory,
      totpSecret: widget.entry.totpSecret,
      websiteUrl: _websiteController.text.trim(),
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );

    ref.read(vaultPasswordsProvider.notifier).updatePassword(updated);
    HappyFeedback.vibrate();
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Credential?'),
        content: Text('Are you sure you want to permanently delete "${widget.entry.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(vaultPasswordsProvider.notifier).deletePassword(widget.entry.id);
              HapticFeedback.heavyImpact();
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
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final categories = [
      for (final c in ref.watch(vaultPasswordsProvider).allCategories)
        if (c.toLowerCase() != 'all') c
    ];
    final isNote = widget.entry.isSecureNote;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNote ? 'Edit Secure Note' : 'Edit Credential',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.entry.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: widget.entry.isFavorite ? AppColors.amber500 : null,
            ),
            tooltip: widget.entry.isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () {
              ref.read(vaultPasswordsProvider.notifier).toggleFavorite(widget.entry.id);
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
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
              // Title / Service Name
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: isNote ? 'Note Title' : 'Title / Service',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Credential Credentials Group (Only for non-notes)
              if (!isNote) ...[
                Text(
                  'CREDENTIALS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: textMuted,
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
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  hintText: 'alex.morgan or email',
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
                      Divider(height: 1, color: borderCol),

                      // ATM PIN Row (Alphanumeric capable)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'ATM PIN',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _pinController,
                                keyboardType: TextInputType.text,
                                obscureText: !_revealPin,
                                enableSuggestions: false,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  hintText: '4-6 digits or alphanumeric (cUdXa)',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _revealPin
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                              ),
                              tooltip: _revealPin ? 'Mask PIN' : 'Show PIN',
                              onPressed: () => setState(() => _revealPin = !_revealPin),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: borderCol),

                      // UPI PIN Row (Alphanumeric capable)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'UPI PIN',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _transactionPinController,
                                keyboardType: TextInputType.text,
                                obscureText: !_revealTransactionPin,
                                enableSuggestions: false,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  hintText: '4 to 6 digit UPI PIN or secret token',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _revealTransactionPin
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                              ),
                              tooltip: _revealTransactionPin ? 'Mask UPI PIN' : 'Show UPI PIN',
                              onPressed: () => setState(() => _revealTransactionPin = !_revealTransactionPin),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Custom Secure Fields Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CUSTOM SECURE FIELDS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
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
                    color: textMuted,
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
                                      setState(() => _selectedCategory = 'Others');
                                    }
                                  },
                                );
                              },
                        child: ChoiceChip(
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
                  color: textMuted,
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
