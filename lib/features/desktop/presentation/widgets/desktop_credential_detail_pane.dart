import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/services/totp_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/core/widgets/character_indexer_chips.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';
import 'package:vaultx/features/vault/presentation/edit_password_screen.dart';
import 'package:vaultx/features/vault/presentation/passwords_vault_screen.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

/// Desktop inline detail pane displaying complete credential secrets,
/// live RFC 6238 TOTP countdown ring, scrambled keypad launcher, and entropy metrics.
class DesktopCredentialDetailPane extends ConsumerStatefulWidget {
  final VaultPasswordEntry? entry;
  final VoidCallback? onEntryDeleted;

  const DesktopCredentialDetailPane({
    super.key,
    required this.entry,
    this.onEntryDeleted,
  });

  @override
  ConsumerState<DesktopCredentialDetailPane> createState() =>
      _DesktopCredentialDetailPaneState();
}

class _DesktopCredentialDetailPaneState
    extends ConsumerState<DesktopCredentialDetailPane> {
  bool _revealPassword = false;
  bool _revealPin = false;
  bool _revealTransactionPin = false;
  final Set<String> _revealedCustomFieldIds = {};

  Timer? _totpTimer;
  String _totpCode = '';
  int _totpSeconds = 30;
  double _totpProgress = 1.0;

  @override
  void initState() {
    super.initState();
    _startTotpTicker();
  }

  @override
  void didUpdateWidget(covariant DesktopCredentialDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry?.id != widget.entry?.id) {
      _revealPassword = false;
      _revealPin = false;
      _revealTransactionPin = false;
      _revealedCustomFieldIds.clear();
      _updateTotp();
    }
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    super.dispose();
  }

  void _startTotpTicker() {
    _updateTotp();
    _totpTimer?.cancel();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateTotp();
      }
    });
  }

  void _updateTotp() {
    final entry = widget.entry;
    if (entry != null && entry.hasTotp) {
      final code = TotpService.generateCode(entry.totpSecret);
      final remaining = TotpService.getRemainingSeconds();
      final progress = TotpService.getRemainingProgress();
      if (_totpCode != code || _totpSeconds != remaining) {
        setState(() {
          _totpCode = code;
          _totpSeconds = remaining;
          _totpProgress = progress;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HappyFeedback.show(
      context,
      message: '$label copied • Auto-clears in 30s',
      icon: Icons.copy_rounded,
    );
  }

  void _confirmDelete() {
    final entry = widget.entry;
    if (entry == null) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text('Are you sure you want to delete "${entry.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(vaultPasswordsProvider.notifier).deletePassword(entry.id);
              widget.onEntryDeleted?.call();
              HappyFeedback.show(context, message: 'Moved "${entry.title}" to trash');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entry = widget.entry;

    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderCol = isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    if (entry == null) {
      return Container(
        color: bgColor,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withAlpha(isDark ? 40 : 25),
                    AppColors.brandPurple.withAlpha(isDark ? 40 : 25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: borderCol, width: 1.5),
              ),
              child: Icon(Icons.shield_outlined, size: 30, color: textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              'Select a credential to inspect',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use arrow keys ↑ ↓ to navigate or press Ctrl + K for omnibar',
              style: TextStyle(fontSize: 12, color: textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final catColor = getCategoryColor(entry.category);
    final entropy = VaultWatchtowerEngine.calculateEntropy(entry.password);
    final entropyLabel = entropy >= 65
        ? 'Very Strong'
        : entropy >= 50
            ? 'Strong'
            : entropy >= 35
                ? 'Moderate'
                : 'Weak';
    final entropyColor = entropy >= 50 ? AppColors.emerald500 : AppColors.amber500;

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          // Top Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withAlpha(isDark ? 45 : 30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: catColor.withAlpha(90), width: 1.2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  entry.isPinOnly || entry.hasPin
                      ? Icons.dialpad_rounded
                      : (entry.isSecureNote ? Icons.note_alt_outlined : Icons.lock_outline_rounded),
                  color: catColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: catColor),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          entry.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Icons: Favorite, Edit, Delete
              Tooltip(
                message: entry.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
                child: IconButton(
                  icon: Icon(
                    entry.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: entry.isFavorite ? AppColors.amber500 : textMuted,
                  ),
                  onPressed: () {
                    ref.read(vaultPasswordsProvider.notifier).toggleFavorite(entry.id);
                  },
                ),
              ),
              Tooltip(
                message: 'Edit credential',
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditPasswordScreen(entry: entry),
                      ),
                    );
                  },
                ),
              ),
              Tooltip(
                message: 'Delete credential',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.rose500),
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Account Credentials Section
          if (entry.username.isNotEmpty || entry.websiteUrl.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                children: [
                  if (entry.username.isNotEmpty)
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Username / Email',
                      value: entry.username,
                      onCopy: () => _copyToClipboard(entry.username, 'Username'),
                      isDark: isDark,
                    ),
                  if (entry.username.isNotEmpty && entry.websiteUrl.isNotEmpty)
                    Divider(height: 1, color: borderCol),
                  if (entry.websiteUrl.isNotEmpty)
                    _DetailRow(
                      icon: Icons.link_rounded,
                      label: 'Website URL',
                      value: entry.websiteUrl,
                      onCopy: () => _copyToClipboard(entry.websiteUrl, 'URL'),
                      isDark: isDark,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Secret / Password / PIN Section
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol, width: 1),
            ),
            child: Column(
              children: [
                // Bank ATM / Primary PIN
                if (entry.hasPin && entry.pin.isNotEmpty) ...[
                  _SecretRow(
                    label: 'Bank / ATM PIN',
                    value: entry.pin,
                    isRevealed: _revealPin,
                    onToggleReveal: () => setState(() => _revealPin = !_revealPin),
                    onCopy: () => _copyToClipboard(entry.pin, 'ATM PIN'),
                    extraAction: Tooltip(
                      message: 'Open Scrambled Anti-Surveillance Keypad',
                      child: IconButton(
                        icon: const Icon(Icons.dialpad_rounded, size: 18, color: AppColors.emerald500),
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: ScrambledPinKeypad(
                                title: '${entry.title} ATM PIN',
                                pin: entry.pin,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    isDark: isDark,
                  ),
                  if (_revealPin && entry.pin.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: CharacterIndexerChips(
                        secret: entry.pin,
                        isRevealed: true,
                        label: 'PIN Character Position Index',
                      ),
                    ),
                  ],
                ],

                // UPI / Transaction PIN
                if (entry.hasPin && entry.transactionPin.isNotEmpty) ...[
                  if (entry.pin.isNotEmpty) Divider(height: 1, color: borderCol),
                  _SecretRow(
                    label: 'UPI / Transaction PIN',
                    value: entry.transactionPin,
                    isRevealed: _revealTransactionPin,
                    onToggleReveal: () =>
                        setState(() => _revealTransactionPin = !_revealTransactionPin),
                    onCopy: () => _copyToClipboard(entry.transactionPin, 'UPI PIN'),
                    isDark: isDark,
                  ),
                  if (_revealTransactionPin && entry.transactionPin.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: CharacterIndexerChips(
                        secret: entry.transactionPin,
                        isRevealed: true,
                        label: 'UPI PIN Character Position Index',
                      ),
                    ),
                  ],
                ],

                // Standard Password
                if (!entry.isPinOnly && entry.password.isNotEmpty) ...[
                  if (entry.hasPin) Divider(height: 1, color: borderCol),
                  _SecretRow(
                    label: 'Password',
                    value: entry.password,
                    isRevealed: _revealPassword,
                    onToggleReveal: () => setState(() => _revealPassword = !_revealPassword),
                    onCopy: () => _copyToClipboard(entry.password, 'Password'),
                    isDark: isDark,
                  ),
                  if (_revealPassword && entry.password.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: CharacterIndexerChips(
                        secret: entry.password,
                        isRevealed: true,
                        label: 'Password Character Position Index',
                      ),
                    ),
                  ],
                  Divider(height: 1, color: borderCol),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Icon(Icons.security_rounded, size: 15, color: entropyColor),
                        Text(
                          '${entropy.toStringAsFixed(1)} bits entropy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: entropyColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: entropyColor.withAlpha(isDark ? 30 : 20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entropyLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: entropyColor,
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

          // Custom Secure Fields Section
          if (entry.hasCustomFields) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          'CUSTOM SECURE FIELDS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(entry.customFields.length, (idx) {
                    final field = entry.customFields[idx];
                    final isRevealed =
                        !field.isConcealed || _revealedCustomFieldIds.contains(field.id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: borderCol),
                        _SecretRow(
                          label: field.label,
                          value: field.value,
                          isRevealed: isRevealed,
                          onToggleReveal: field.isConcealed
                              ? () {
                                  setState(() {
                                    if (_revealedCustomFieldIds.contains(field.id)) {
                                      _revealedCustomFieldIds.remove(field.id);
                                    } else {
                                      _revealedCustomFieldIds.add(field.id);
                                    }
                                  });
                                }
                              : null,
                          onCopy: () => _copyToClipboard(field.value, field.label),
                          isDark: isDark,
                        ),
                        if (isRevealed && field.value.length >= 2) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: CharacterIndexerChips(
                              secret: field.value,
                              isRevealed: true,
                              label: '${field.label} Character Index',
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Two-Factor Authenticator (TOTP) Card
          if (entry.hasTotp) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Two-Factor Authenticator (TOTP)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Formatted 6-Digit Code
                      Expanded(
                        child: Text(
                          _totpCode.length == 6
                              ? '${_totpCode.substring(0, 3)} ${_totpCode.substring(3)}'
                              : _totpCode,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.0,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),

                      // Countdown Progress Ring
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _totpProgress,
                              strokeWidth: 3.0,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              color: _totpSeconds <= 5
                                  ? AppColors.rose500
                                  : AppColors.primaryBlue,
                            ),
                            Text(
                              '$_totpSeconds',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Copy TOTP Button
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy 2FA Code',
                        onPressed: () => _copyToClipboard(_totpCode, 'TOTP Code'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Secure Notes Card
          if (entry.notes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 16, color: textMuted),
                          const SizedBox(width: 8),
                          Text(
                            'Encrypted Notes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy Notes',
                        onPressed: () => _copyToClipboard(entry.notes, 'Notes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    entry.notes,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Timestamps Metadata
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  'Created ${_formatDate(entry.createdAt)}',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
                if (entry.updatedAt.isAfter(entry.createdAt)) ...[
                  Text('•', style: TextStyle(fontSize: 11, color: textMuted)),
                  Text(
                    'Updated ${_formatDate(entry.updatedAt)}',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool isDark;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy $label',
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _SecretRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isRevealed;
  final VoidCallback? onToggleReveal;
  final VoidCallback onCopy;
  final Widget? extraAction;
  final bool isDark;

  const _SecretRow({
    required this.label,
    required this.value,
    required this.isRevealed,
    this.onToggleReveal,
    required this.onCopy,
    this.extraAction,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.key_rounded, size: 18, color: textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  isRevealed ? value : ('● ' * value.length.clamp(4, 16)).trim(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: isRevealed ? 0.5 : 2.0,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (extraAction != null) extraAction!,
          if (onToggleReveal != null)
            IconButton(
              icon: Icon(
                isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: isRevealed ? 'Hide $label' : 'Reveal $label',
              onPressed: onToggleReveal,
            ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy $label',
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
