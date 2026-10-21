import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/theme_provider.dart';
import 'package:vaultx/core/widgets/expressive/expressive.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/settings/presentation/change_master_password_dialog.dart';
import 'package:vaultx/features/settings/presentation/providers/auto_lock_provider.dart';
import 'package:vaultx/features/settings/presentation/providers/biometric_preference_provider.dart';
import 'package:vaultx/features/sync/presentation/sync_screen.dart';
import 'package:vaultx/features/backup/presentation/backup_restore_screen.dart';

/// Screen 8: Settings & Theme Switcher Screen
///
/// Implements appearance settings with live Dark/Light theme switching modal dialog,
/// security preferences, data/sync options, and cryptographic wipe danger zone.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _confirmWipe(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Wipe All Data?',
          style: TextStyle(color: AppColors.rose500, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'WARNING: This is completely irreversible. All encrypted passwords, cards, and keys will be permanently deleted from the platform secure enclave.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose500,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(authSessionProvider.notifier).wipeAllData();
              await HapticFeedback.heavyImpact();
              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.rose500,
                    content: Text('Vault data completely erased.'),
                  ),
                );
              }
            },
            child: const Text('Wipe Everything'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    final dialogBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderCol),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'App Version',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Version row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Version', style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w500)),
                        const Text(
                          '1.0.0 (Build 1)',
                          style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Architecture row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: AppColors.emerald500, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Security Architecture', style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w500)),
                          const Text(
                            'Argon2id KDF + AES-256-GCM\n+ Hardware Enclave',
                            style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
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

  void _openAutoLockDialog(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(autoLockProvider);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
            final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: borderCol),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Auto-Lock Duration',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lock vault after closing or backgrounding app',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...AutoLockDuration.values.map((option) {
                      final isSelected = current == option;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(autoLockProvider.notifier).setDuration(option);
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue.withAlpha(isDark ? 50 : 30)
                                  : (isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryBlue : borderCol,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryBlue,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final autoLock = ref.watch(autoLockProvider);
    final biometricEnabled = ref.watch(biometricPreferenceProvider);
    final authState = ref.watch(authSessionProvider);
    // Use the live animated theme brightness so card/border colours
    // crossfade in sync with MaterialApp's AnimatedTheme rather than
    // snapping one frame ahead of the interpolated scaffold background.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: APPEARANCE
              const _SectionHeader(title: 'APPEARANCE'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          themeMode == ThemeMode.dark
                              ? Icons.dark_mode_rounded
                              : themeMode == ThemeMode.light
                                  ? Icons.light_mode_rounded
                                  : Icons.brightness_auto_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Theme',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ExpressiveSegmentedButton<ThemeMode>(
                      items: const [
                        ThemeMode.dark,
                        ThemeMode.light,
                      ],
                      selectedItem: themeMode == ThemeMode.system ? ThemeMode.dark : themeMode,
                      onSelected: (mode) {
                        HapticFeedback.selectionClick();
                        if (mode == ThemeMode.dark) {
                          ref.read(themeModeProvider.notifier).setDark();
                        } else {
                          ref.read(themeModeProvider.notifier).setLight();
                        }
                      },
                      itemBuilder: (context, mode, isSelected) {
                        final (icon, label) = mode == ThemeMode.dark
                            ? (Icons.dark_mode_rounded, 'Dark')
                            : (Icons.light_mode_rounded, 'Light');
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: SECURITY
              const _SectionHeader(title: 'SECURITY'),
              Material(
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: borderCol),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.password_rounded, color: AppColors.primaryBlue),
                      title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const ChangeMasterPasswordDialog(),
                        );
                      },
                    ),
                    Divider(height: 1, color: borderCol),
                    ListTile(
                      leading: Icon(
                        Icons.fingerprint_rounded,
                        color: authState.isBiometricsAvailable
                            ? AppColors.primaryBlue
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      title: const Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        authState.isBiometricsAvailable
                            ? (biometricEnabled ? 'Fingerprint unlock enabled' : 'Disabled — tap to verify fingerprint')
                            : 'No biometrics enrolled on this device',
                        style: TextStyle(
                          fontSize: 12,
                          color: authState.isBiometricsAvailable
                              ? null
                              : AppColors.amber500,
                        ),
                      ),
                      onTap: authState.isBiometricsAvailable
                          ? () async {
                              final targetVal = !biometricEnabled;
                              if (targetVal) {
                                final success = await ref
                                    .read(biometricPreferenceProvider.notifier)
                                    .setEnabled(true);
                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppColors.emerald500,
                                        duration: Duration(milliseconds: 1200),
                                        behavior: SnackBarBehavior.floating,
                                        content: Row(
                                          children: [
                                            Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text('Biometric authentication enabled'),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppColors.rose500,
                                        duration: Duration(milliseconds: 1200),
                                        behavior: SnackBarBehavior.floating,
                                        content: Text('Biometric verification cancelled or failed.'),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                await ref.read(biometricPreferenceProvider.notifier).setEnabled(false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      duration: Duration(milliseconds: 1200),
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('Biometric authentication disabled.'),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      trailing: Switch.adaptive(
                        value: biometricEnabled,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: authState.isBiometricsAvailable
                            ? (val) async {
                                if (val) {
                                  final success = await ref
                                      .read(biometricPreferenceProvider.notifier)
                                      .setEnabled(true);
                                  if (context.mounted) {
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppColors.emerald500,
                                          duration: Duration(milliseconds: 1200),
                                          behavior: SnackBarBehavior.floating,
                                          content: Row(
                                            children: [
                                              Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                                              SizedBox(width: 8),
                                              Text('Biometric authentication enabled'),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppColors.rose500,
                                          duration: Duration(milliseconds: 1200),
                                          behavior: SnackBarBehavior.floating,
                                          content: Text('Biometric verification cancelled or failed.'),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  await ref.read(biometricPreferenceProvider.notifier).setEnabled(false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        duration: Duration(milliseconds: 1200),
                                        behavior: SnackBarBehavior.floating,
                                        content: Text('Biometric authentication disabled.'),
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                      ),
                    ),
                    Divider(height: 1, color: borderCol),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined, color: AppColors.primaryBlue),
                      title: const Text('Auto-Lock Duration', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Lock vault after closing app'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            autoLock.label,
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                      onTap: () => _openAutoLockDialog(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: DATA & SYNC
              const _SectionHeader(title: 'DATA & SYNC'),
              Material(
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: borderCol),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.sync_rounded, color: AppColors.primaryBlue),
                      title: const Text('Sync with Devices', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Device-to-device mDNS & WSS pairing'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SyncScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: borderCol),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_rounded, color: AppColors.primaryBlue),
                      title: const Text('Backup Vault', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Export encrypted .vxb backup file'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BackupRestoreScreen(initialTabIndex: 0),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: borderCol),
                    ListTile(
                      leading: const Icon(Icons.cloud_download_rounded, color: AppColors.primaryBlue),
                      title: const Text('Restore Vault', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Restore from .vxb backup file'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BackupRestoreScreen(initialTabIndex: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: ABOUT
              const _SectionHeader(title: 'ABOUT'),
              Material(
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: borderCol),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue),
                  title: const Text('App Version', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('1.0.0 (Build 1)', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showAppInfoDialog(context, isDark),
                ),
              ),
              const SizedBox(height: 24),

              // DANGER ZONE
              const _SectionHeader(title: 'DANGER ZONE'),
              Material(
                color: isDark
                    ? AppColors.rose950.withAlpha(80)
                    : AppColors.rose500.withAlpha(30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: AppColors.rose500.withAlpha(isDark ? 80 : 160),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: isDark
                        ? AppColors.rose400
                        : const Color(0xFFBE123C), // rose-700
                  ),
                  title: Text(
                    'Wipe All Data',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.rose400
                          : const Color(0xFFBE123C), // rose-700
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Irreversible cryptographic erasure',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFFFD1D1)
                          : const Color(0xFF9F1239), // rose-800, readable on light bg
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    Icons.warning_amber_rounded,
                    color: isDark
                        ? AppColors.rose400
                        : const Color(0xFFBE123C), // rose-700
                  ),
                  onTap: () => _confirmWipe(context, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }
}
