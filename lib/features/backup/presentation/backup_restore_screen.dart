import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/happy_feedback.dart';
import '../../vault/presentation/providers/vault_passwords_provider.dart';
import '../../wallet/presentation/providers/wallet_cards_provider.dart';
import '../domain/vxb_backup_service.dart';
import 'import_credentials_dialog.dart';
import 'providers/backup_restore_provider.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const BackupRestoreScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Backup Form State
  final _backupPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureBackupPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isExporting = false;
  File? _lastExportedFile;

  // Restore Form State
  String? _selectedFilePath;
  String? _selectedFileName;
  final _restorePasswordController = TextEditingController();
  bool _obscureRestorePassword = true;
  bool _isInspecting = false;
  bool _isRestoring = false;
  VxbBackupPayload? _inspectedPayload;
  bool _replaceExisting = false; // default to Merge

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _backupPasswordController.dispose();
    _confirmPasswordController.dispose();
    _restorePasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final password = _backupPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty) {
      _showSnackbar('Please enter a backup password', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnackbar('Backup password must be at least 6 characters', isError: true);
      return;
    }
    if (password != confirm) {
      _showSnackbar('Passwords do not match', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final File file = await ref.read(backupRestoreProvider.notifier).exportBackup(
            backupPassword: password,
            shareAfterExport: true,
          );

      setState(() {
        _lastExportedFile = file;
        _backupPasswordController.clear();
        _confirmPasswordController.clear();
      });

      if (mounted) {
        HappyFeedback.show(
          context,
          message: 'Encrypted .vxb backup exported successfully.',
          title: 'Backup Created',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Export failed: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickBackupFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        if (file.path != null) {
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            _inspectedPayload = null; // reset previous inspection
          });
        }
      }
    } catch (e) {
      _showSnackbar('Error picking file: $e', isError: true);
    }
  }

  Future<void> _handleInspect() async {
    if (_selectedFilePath == null) {
      _showSnackbar('Please select a .vxb backup file first', isError: true);
      return;
    }
    final password = _restorePasswordController.text;
    if (password.isEmpty) {
      _showSnackbar('Please enter the backup password', isError: true);
      return;
    }

    setState(() => _isInspecting = true);
    try {
      final VxbBackupPayload payload =
          await ref.read(backupRestoreProvider.notifier).inspectBackup(
                filePath: _selectedFilePath!,
                backupPassword: password,
              );

      setState(() {
        _inspectedPayload = payload;
      });

      await HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() => _inspectedPayload = null);
      if (mounted) {
        _showSnackbar(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isInspecting = false);
    }
  }

  Future<void> _handleApplyRestore() async {
    if (_inspectedPayload == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _replaceExisting ? 'Replace Entire Vault?' : 'Merge Backup Data?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _replaceExisting
              ? 'WARNING: This will replace all existing passwords and cards in your vault with ${_inspectedPayload!.passwords.length} passwords and ${_inspectedPayload!.cards.length} cards from the backup.'
              : 'This will merge ${_inspectedPayload!.passwords.length} passwords and ${_inspectedPayload!.cards.length} cards into your current vault without deleting existing items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _replaceExisting ? AppColors.rose500 : AppColors.primaryBlue,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_replaceExisting ? 'Replace Vault' : 'Confirm Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    try {
      final report = await ref.read(backupRestoreProvider.notifier).applyRestore(
            payload: _inspectedPayload!,
            replaceExisting: _replaceExisting,
          );

      if (mounted) {
        HappyFeedback.show(
          context,
          title: 'Vault Restored',
          message:
              'Restored ${report.passwordsRestored} passwords and ${report.cardsRestored} cards (${report.isMerged ? 'Merged' : 'Replaced'}).',
        );

        setState(() {
          _inspectedPayload = null;
          _selectedFilePath = null;
          _selectedFileName = null;
          _restorePasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Restore failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.rose500 : AppColors.emerald500,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Backup & Restore',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          tabs: const [
            Tab(text: 'Export Backup', icon: Icon(Icons.cloud_upload_outlined, size: 20)),
            Tab(text: 'Restore Vault', icon: Icon(Icons.cloud_download_outlined, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(isDark, cardBg, borderCol),
          _buildRestoreTab(isDark, cardBg, borderCol),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: EXPORT BACKUP
  // ─────────────────────────────────────────────────────────────
  Widget _buildExportTab(bool isDark, Color cardBg, Color borderCol) {
    final passwords = ref.watch(vaultPasswordsProvider).allEntries;
    final cards = ref.watch(walletCardsProvider).allCards;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // Summary & Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Encrypted VaultX Backup (.vxb)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${passwords.length} Passwords  •  ${cards.length} Cards',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Creates a 100% offline AES-256 encrypted backup file compatible with both VaultX mobile and desktop apps. Set a secure backup password below.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Password Configuration
        Text(
          'SET BACKUP PASSWORD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _backupPasswordController,
          obscureText: _obscureBackupPassword,
          decoration: InputDecoration(
            labelText: 'Backup Password',
            hintText: 'Minimum 6 characters',
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureBackupPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureBackupPassword = !_obscureBackupPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter backup password',
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 28),

        // Export CTA
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _isExporting ? null : _handleExport,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined, size: 22),
            label: Text(_isExporting ? 'Exporting...' : 'Export .vxb Backup', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),

        if (_lastExportedFile != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.emerald500.withAlpha(isDark ? 35 : 20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.emerald500.withAlpha(isDark ? 90 : 120)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.emerald500, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Export Complete',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        _lastExportedFile!.path.split(Platform.pathSeparator).last,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: RESTORE VAULT
  // ─────────────────────────────────────────────────────────────
  Widget _buildRestoreTab(bool isDark, Color cardBg, Color borderCol) {
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // Universal CSV/JSON Importer Banner
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(isDark ? 35 : 20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withAlpha(90)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(isDark ? 50 : 30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.file_download_outlined, color: AppColors.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Migrate from Other Managers',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Import Chrome, Bitwarden, or 1Password CSV/JSON',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showDialog<void>(
                    context: context,
                    builder: (_) => const ImportCredentialsDialog(),
                  );
                },
                child: const Text('Import', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ),

        // Select File Card
        InkWell(
          onTap: _pickBackupFile,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedFilePath != null ? AppColors.primaryBlue : borderCol,
                width: _selectedFilePath != null ? 1.6 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _selectedFilePath != null ? Icons.description_rounded : Icons.folder_open_rounded,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFileName ?? 'Select .vxb Backup File',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFilePath != null
                            ? 'Tap to select a different file'
                            : 'Supports VaultX format (.vxb)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Decrypt Password
        TextField(
          controller: _restorePasswordController,
          obscureText: _obscureRestorePassword,
          decoration: InputDecoration(
            labelText: 'Backup Decryption Password',
            hintText: 'Enter password used during export',
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.key_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRestorePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureRestorePassword = !_obscureRestorePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),

        // Inspect Button
        OutlinedButton.icon(
          onPressed: _isInspecting || _selectedFilePath == null ? null : _handleInspect,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: _isInspecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open_rounded, size: 20),
          label: const Text('Inspect & Decrypt Backup', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 24),

        // Inspected Payload Preview
        if (_inspectedPayload != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primaryBlue.withAlpha(120), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Backup Contents Validated',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.emerald500.withAlpha(60)),
                      ),
                      child: Text(
                        'v${_inspectedPayload!.version}',
                        style: const TextStyle(
                          color: AppColors.emerald500,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatBadge(
                        label: 'Passwords',
                        count: '${_inspectedPayload!.passwords.length}',
                        icon: Icons.password_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBadge(
                        label: 'Cards',
                        count: '${_inspectedPayload!.cards.length}',
                        icon: Icons.credit_card_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Created on ${_inspectedPayload!.timestamp.toLocal().toString().substring(0, 16)}',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 20),

                // Mode Selector
                const Text(
                  'RESTORE MODE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                _ModeSelectionTile(
                  title: 'Merge Vault (Recommended)',
                  subtitle: 'Adds backup entries to your current vault without deleting anything',
                  isSelected: !_replaceExisting,
                  activeColor: AppColors.primaryBlue,
                  onTap: () => setState(() => _replaceExisting = false),
                ),
                const SizedBox(height: 8),
                _ModeSelectionTile(
                  title: 'Replace Entire Vault',
                  subtitle: 'Replaces all existing vault entries with the backup data',
                  isSelected: _replaceExisting,
                  activeColor: AppColors.rose500,
                  onTap: () => setState(() => _replaceExisting = true),
                ),
                const SizedBox(height: 20),

                // Restore CTA
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isRestoring ? null : _handleApplyRestore,
                    style: FilledButton.styleFrom(
                      backgroundColor: _replaceExisting ? AppColors.rose500 : AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isRestoring
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cloud_download_rounded, size: 22),
                    label: Text(
                      _isRestoring
                          ? 'Restoring...'
                          : (_replaceExisting ? 'Replace Vault with Backup' : 'Restore & Merge Vault'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeSelectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeSelectionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : borderCol,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? activeColor : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected ? activeColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String count;
  final IconData icon;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
