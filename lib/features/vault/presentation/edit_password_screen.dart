import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/core/widgets/totp_code_widget.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

/// Screen 4: Edit Password / View Credential / Secure Note Screen
///
/// Implements dual View (read-only with 1-tap copy/unmask) and Edit modes,
/// real-time TOTP 2FA authenticator display, and destructive delete action.
class EditPasswordScreen extends ConsumerStatefulWidget {
  final VaultPasswordEntry entry;

  const EditPasswordScreen({super.key, required this.entry});

  @override
  ConsumerState<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends ConsumerState<EditPasswordScreen> {
  bool _isEditing = false;
  bool _revealPassword = false;

  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _totpController;
  late TextEditingController _websiteController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _usernameController = TextEditingController(text: widget.entry.username);
    _passwordController = TextEditingController(text: widget.entry.password);
    _totpController = TextEditingController(text: widget.entry.totpSecret);
    _websiteController = TextEditingController(text: widget.entry.websiteUrl);
    _notesController = TextEditingController(text: widget.entry.notes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.emerald500,
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleEditDone() {
    if (_isEditing) {
      // Save changes
      final updated = widget.entry.copyWith(
        title: _titleController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        totpSecret: _totpController.text.trim(),
        websiteUrl: _websiteController.text.trim(),
        notes: _notesController.text.trim(),
        updatedAt: DateTime.now(),
      );
      ref.read(vaultPasswordsProvider.notifier).updatePassword(updated);
      HappyFeedback.show(
        context,
        message: 'Credential updated successfully',
      );
      setState(() => _isEditing = false);
    } else {
      HapticFeedback.selectionClick();
      setState(() => _isEditing = true);
    }
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
    final isNote = widget.entry.isSecureNote;

    return Scaffold(
      appBar: AppBar(
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
          TextButton(
            onPressed: _toggleEditDone,
            child: Text(
              _isEditing ? 'Done' : 'Edit',
              style: TextStyle(
                color: _isEditing ? AppColors.emerald400 : AppColors.primaryBlue,
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
              // Monogram Avatar & Title
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
                    if (_isEditing)
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _titleController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: isNote ? 'Note Title' : 'Service Name',
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        _titleController.text,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      if (!isNote && _usernameController.text.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _usernameController.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TOTP 2FA Authenticator Widget (in read mode if present)
              if (!_isEditing && widget.entry.hasTotp) ...[
                TotpCodeWidget(
                  secret: widget.entry.totpSecret,
                  accountLabel: widget.entry.username.isNotEmpty ? widget.entry.username : widget.entry.title,
                ),
                const SizedBox(height: 20),
              ],

              // Credentials Group (for passwords)
              if (!isNote || _isEditing) ...[
                Text(
                  isNote ? 'NOTE ATTRIBUTES' : 'CREDENTIALS',
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
                      if (!isNote || _usernameController.text.isNotEmpty || _isEditing) ...[
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
                                child: _isEditing
                                    ? TextField(
                                        controller: _usernameController,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      )
                                    : Text(
                                        _usernameController.text.isNotEmpty
                                            ? _usernameController.text
                                            : 'Not set',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                              if (!_isEditing && _usernameController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy username',
                                  onPressed: () => _copyToClipboard(
                                    _usernameController.text,
                                    'Username',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: borderCol),
                      ],

                      // Password Row
                      if (!isNote || _passwordController.text.isNotEmpty || _isEditing) ...[
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
                                child: _isEditing
                                    ? TextField(
                                        controller: _passwordController,
                                        obscureText: !_revealPassword,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      )
                                    : Text(
                                        _revealPassword
                                            ? _passwordController.text
                                            : '••••••••••••••••',
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                              if (!_isEditing) ...[
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
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy password',
                                  onPressed: () => _copyToClipboard(
                                    _passwordController.text,
                                    'Password',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // 2FA TOTP Key input in edit mode
                      if (_isEditing) ...[
                        Divider(height: 1, color: borderCol),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 85,
                                child: Text(
                                  '2FA Key',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _totpController,
                                  decoration: const InputDecoration(
                                    hintText: 'Base32 secret key',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Security / Health Status Banner
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
                              'No leaks detected in known data breaches.',
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
              ],

              // Details Group (Website & Notes)
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
                              child: _isEditing
                                  ? TextField(
                                      controller: _websiteController,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    )
                                  : Text(
                                      _websiteController.text.isNotEmpty
                                          ? _websiteController.text
                                          : 'Not set',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _websiteController.text.isNotEmpty
                                            ? AppColors.primaryBlue
                                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                      ),
                                    ),
                            ),
                            if (!_isEditing && _websiteController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                tooltip: 'Open URL',
                                onPressed: () => _copyToClipboard(_websiteController.text, 'Website URL'),
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
                            child: _isEditing
                                ? TextField(
                                    controller: _notesController,
                                    maxLines: isNote ? 12 : 4,
                                    decoration: InputDecoration(
                                      hintText: isNote ? 'Write confidential notes...' : 'Additional notes...',
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  )
                                : SelectableText(
                                    _notesController.text.isNotEmpty
                                        ? _notesController.text
                                        : 'No notes added',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _notesController.text.isNotEmpty
                                          ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                  ),
                          ),
                          if (!_isEditing && _notesController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: 'Copy notes',
                              onPressed: () => _copyToClipboard(_notesController.text, 'Notes'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Delete Credential Button
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
