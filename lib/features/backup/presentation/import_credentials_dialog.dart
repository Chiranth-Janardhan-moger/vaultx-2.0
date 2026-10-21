import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/features/backup/domain/vault_importer_service.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

/// Modal dialog for importing credentials from Google Chrome, Bitwarden, or 1Password.
class ImportCredentialsDialog extends ConsumerStatefulWidget {
  const ImportCredentialsDialog({super.key});

  @override
  ConsumerState<ImportCredentialsDialog> createState() => _ImportCredentialsDialogState();
}

class _ImportCredentialsDialogState extends ConsumerState<ImportCredentialsDialog> {
  bool _isLoading = false;
  String? _selectedFileName;
  ImportResult? _importResult;
  String? _errorMessage;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json', 'txt'],
      );

      if (files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = files.first;
      String content = '';

      if (file.path != null) {
        content = await File(file.path!).readAsString();
      }

      final parsed = VaultImporterService.parse(content);
      setState(() {
        _selectedFileName = file.name;
        _importResult = parsed;
        _isLoading = false;
        if (parsed.hasError) {
          _errorMessage = parsed.errorMessage;
        } else if (parsed.isEmpty) {
          _errorMessage = 'No valid credentials found in file.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to read file: $e';
      });
    }
  }

  void _executeImport() {
    final result = _importResult;
    if (result == null || result.isEmpty) return;

    final notifier = ref.read(vaultPasswordsProvider.notifier);
    for (final entry in result.entries) {
      notifier.addPassword(entry);
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.emerald500,
        content: Text(
          'Successfully imported ${result.totalCount} credentials into vault.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderCol),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.file_download_outlined, color: AppColors.primaryBlue, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Import Credentials',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Supports CSV and JSON exports from Google Chrome, Bitwarden, and 1Password.',
                style: TextStyle(fontSize: 13, color: mutedCol),
              ),
              const SizedBox(height: 16),

              // Pick File Button or File Status Card
              if (_selectedFileName == null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: AppColors.primaryBlue.withAlpha(120), width: 1.5),
                  ),
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 24, color: AppColors.primaryBlue),
                  label: _isLoading
                      ? const Text('Reading file...')
                      : const Text(
                          'Choose CSV or JSON File',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: AppColors.primaryBlue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName!,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_importResult != null && !_importResult!.hasError)
                              Text(
                                '${_importResult!.source.label} · ${_importResult!.totalCount} items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.emerald500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _pickFile,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.rose500.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.rose500.withAlpha(90)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.rose500, fontSize: 12),
                  ),
                ),
              ],

              // Preview list of entries
              if (_importResult != null && _importResult!.entries.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'PREVIEW (${_importResult!.totalCount} ITEMS)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: mutedCol,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderCol),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _importResult!.entries.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: borderCol),
                      itemBuilder: (context, idx) {
                        final item = _importResult!.entries[idx];
                        return ListTile(
                          dense: true,
                          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            item.username.isNotEmpty ? item.username : (item.websiteUrl.isNotEmpty ? item.websiteUrl : 'No username'),
                            style: TextStyle(fontSize: 12, color: mutedCol),
                          ),
                          trailing: item.hasTotp
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '2FA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ] else
                const Spacer(),

              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (_importResult != null && _importResult!.entries.isNotEmpty)
                        ? _executeImport
                        : null,
                    child: Text(
                      _importResult != null
                          ? 'Import ${_importResult!.totalCount} Items'
                          : 'Import',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
