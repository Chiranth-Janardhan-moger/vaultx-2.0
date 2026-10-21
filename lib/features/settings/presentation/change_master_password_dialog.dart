import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';

/// Modal dialog that lets the authenticated user change their master password.
///
/// Validates the current password (via Argon2id constant-time comparison),
/// enforces new-password strength, and updates secure storage atomically.
class ChangeMasterPasswordDialog extends ConsumerStatefulWidget {
  const ChangeMasterPasswordDialog({super.key});

  @override
  ConsumerState<ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends ConsumerState<ChangeMasterPasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Password-strength indicator
  // ---------------------------------------------------------------------------

  int _strengthScore(String pw) {
    if (pw.isEmpty) return 0;
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 12) score++;
    if (pw.contains(RegExp(r'[A-Z]'))) score++;
    if (pw.contains(RegExp(r'[0-9]'))) score++;
    if (pw.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score; // 0-5
  }

  Color _strengthColor(int score) {
    if (score <= 1) return AppColors.rose500;
    if (score <= 2) return AppColors.amber500;
    if (score <= 3) return AppColors.amber400;
    return AppColors.emerald500;
  }

  String _strengthLabel(int score) {
    if (score == 0) return '';
    if (score <= 1) return 'Very weak';
    if (score <= 2) return 'Weak';
    if (score == 3) return 'Fair';
    if (score == 4) return 'Strong';
    return 'Very strong';
  }

  // ---------------------------------------------------------------------------
  // Submission
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    // Client-side validation
    if (current.isEmpty) {
      setState(() => _errorMessage = 'Please enter your current master password.');
      return;
    }
    if (newPw.length < 8) {
      setState(() => _errorMessage = 'New password must be at least 8 characters.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _errorMessage = 'New passwords do not match.');
      return;
    }
    if (newPw == current) {
      setState(() => _errorMessage = 'New password must differ from the current one.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(authSessionProvider.notifier).changeMasterPassword(
          currentPassword: current,
          newPassword: newPw,
        );

    if (!mounted) return;

    switch (result) {
      case ChangeMasterPasswordResult.success:
        unawaited(HapticFeedback.heavyImpact());
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald500,
            duration: const Duration(milliseconds: 1200),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  'Master password updated successfully.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      case ChangeMasterPasswordResult.incorrectCurrentPassword:
        unawaited(HapticFeedback.vibrate());
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect current password. Please try again.';
        });
      case ChangeMasterPasswordResult.weakNewPassword:
        setState(() {
          _isLoading = false;
          _errorMessage = 'New password must be at least 8 characters.';
        });
      case ChangeMasterPasswordResult.vaultNotInitialized:
        setState(() {
          _isLoading = false;
          _errorMessage = 'Vault is not initialized. Please set up your vault first.';
        });
      case ChangeMasterPasswordResult.unexpectedError:
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final newPw = _newCtrl.text;
    final score = _strengthScore(newPw);
    final strengthColor = _strengthColor(score);
    final strengthLabel = _strengthLabel(score);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderCol),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withAlpha(isDark ? 50 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Change Master Password',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your vault will remain unlocked after the change.',
              style: TextStyle(fontSize: 12, color: mutedColor),
            ),
            const SizedBox(height: 22),

            // ── Current password ────────────────────────────────────────────
            _FieldLabel(label: 'Current Password', color: mutedColor),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _currentCtrl,
              obscure: _obscureCurrent,
              hintText: 'Enter current master password',
              inputBg: inputBg,
              borderCol: borderCol,
              enabled: !_isLoading,
              onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 16),

            // ── New password ────────────────────────────────────────────────
            _FieldLabel(label: 'New Password', color: mutedColor),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _newCtrl,
              obscure: _obscureNew,
              hintText: 'Min. 8 characters',
              inputBg: inputBg,
              borderCol: borderCol,
              enabled: !_isLoading,
              onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              onChanged: (_) => setState(() {}),
            ),

            // Strength bar
            if (newPw.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 5,
                  minHeight: 4,
                  backgroundColor: borderCol,
                  valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strengthLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: strengthColor,
                    ),
                  ),
                  Text(
                    '${newPw.length} chars',
                    style: TextStyle(fontSize: 11, color: mutedColor),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // ── Confirm new password ────────────────────────────────────────
            _FieldLabel(label: 'Confirm New Password', color: mutedColor),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _confirmCtrl,
              obscure: _obscureConfirm,
              hintText: 'Re-enter new master password',
              inputBg: inputBg,
              borderCol: borderCol,
              enabled: !_isLoading,
              onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              // Highlight mismatch in real-time
              overrideBorderColor: _confirmCtrl.text.isNotEmpty && _confirmCtrl.text != _newCtrl.text
                  ? AppColors.rose500
                  : null,
            ),

            // ── Error message ───────────────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.rose500.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.rose500.withAlpha(100)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.rose400, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.rose400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Security note ───────────────────────────────────────────────
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(isDark ? 30 : 15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withAlpha(60)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primaryBlue, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A new Argon2id salt will be generated. '
                      'Key derivation may take a few seconds.',
                      style: TextStyle(fontSize: 11, color: mutedColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Action buttons ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderCol),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primaryBlue.withAlpha(120),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Password',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _FieldLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final String hintText;
  final Color inputBg;
  final Color borderCol;
  final bool enabled;
  final VoidCallback onToggleObscure;
  final ValueChanged<String>? onChanged;
  final Color? overrideBorderColor;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.hintText,
    required this.inputBg,
    required this.borderCol,
    required this.enabled,
    required this.onToggleObscure,
    this.onChanged,
    this.overrideBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = overrideBorderColor ?? borderCol;
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectiveBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectiveBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: overrideBorderColor ?? AppColors.primaryBlue,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectiveBorder.withAlpha(100)),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
          onPressed: enabled ? onToggleObscure : null,
        ),
      ),
    );
  }
}
