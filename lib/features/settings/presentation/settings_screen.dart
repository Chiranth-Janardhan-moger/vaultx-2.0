import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/theme_provider.dart';
import 'package:vaultx/core/widgets/expressive/expressive.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/services/screen_security_service.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/settings/presentation/change_master_password_dialog.dart';
import 'package:vaultx/features/settings/presentation/providers/auto_lock_provider.dart';
import 'package:vaultx/features/settings/presentation/providers/biometric_preference_provider.dart';
import 'package:vaultx/features/sync/presentation/sync_screen.dart';
import 'package:vaultx/features/backup/presentation/backup_restore_screen.dart';

/// Opens the irreversible cryptographic wipe confirmation dialog.
void confirmWipeData(BuildContext context, WidgetRef ref) {
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

/// Opens the modal selector for auto-lock timeout.
void openAutoLockDialog(BuildContext context, WidgetRef ref) {
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

/// Opens the modal selector for clipboard auto-clear timeout.
void openClipboardTimeoutDialog(BuildContext context, WidgetRef ref) {
  HapticFeedback.lightImpact();
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(clipboardTimeoutProvider);
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
                        'Clipboard Auto-Clear',
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
                    'Automatically wipe copied secrets from clipboard',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...ClipboardTimeout.values.map((option) {
                    final isSelected = current == option;
                    final displayLabel = option == ClipboardTimeout.off
                        ? 'Off (Never clear)'
                        : '${option.label} (${option.duration.inSeconds} seconds)';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(clipboardTimeoutProvider.notifier).setDuration(option);
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
                                displayLabel,
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

/// Screen 8: Settings Hub Screen
///
/// Compact, clear settings directory divided into General, Sync, Backup & Restore,
/// and App Info (containing versioning, cryptographic architecture, and the wipe data danger zone).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

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
              const SizedBox(height: 4),
              Text(
                'Preferences, sync, backup & security',
                style: TextStyle(
                  fontSize: 14,
                  color: mutedCol,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // 1. GENERAL
              _SettingsNavTile(
                icon: Icons.tune_rounded,
                iconColor: AppColors.primaryBlue,
                title: 'General',
                subtitle: 'Theme, Biometrics, Auto-Lock & Master Password',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const GeneralSettingsScreen()),
                  );
                },
              ),

              // 2. SYNC
              _SettingsNavTile(
                icon: Icons.sync_rounded,
                iconColor: AppColors.brandPurple,
                title: 'Sync',
                subtitle: 'Peer-to-peer local device synchronization',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                  );
                },
              ),

              // 3. BACKUP & RESTORE
              _SettingsNavTile(
                icon: Icons.cloud_sync_rounded,
                iconColor: AppColors.emerald500,
                title: 'Backup & Restore',
                subtitle: 'Export & restore encrypted .vxb backup files',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BackupRestoreScreen()),
                  );
                },
              ),

              // 4. APP INFO
              _SettingsNavTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.amber500,
                title: 'App Info',
                subtitle: 'Version 1.0.0, Architecture & Wipe All Data',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AppInfoScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// General Settings Screen
///
/// Houses Appearance (System, Dark, Light theme modes) and Security Preferences
/// (Master Password, Biometric Authentication, Auto-Lock Duration).
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final autoLock = ref.watch(autoLockProvider);
    final biometricEnabled = ref.watch(biometricPreferenceProvider);
    final authState = ref.watch(authSessionProvider);
    final screenSecurity = ref.watch(screenSecurityProvider);
    final clipboardTimeout = ref.watch(clipboardTimeoutProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'General',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          themeMode == ThemeMode.system
                              ? Icons.brightness_auto_rounded
                              : themeMode == ThemeMode.dark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
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
                        ThemeMode.system,
                        ThemeMode.dark,
                        ThemeMode.light,
                      ],
                      selectedItem: themeMode,
                      onSelected: (mode) {
                        HapticFeedback.selectionClick();
                        ref.read(themeModeProvider.notifier).setMode(mode);
                      },
                      itemBuilder: (context, mode, isSelected) {
                        final (icon, label) = switch (mode) {
                          ThemeMode.system => (Icons.brightness_auto_rounded, 'System'),
                          ThemeMode.dark => (Icons.dark_mode_rounded, 'Dark'),
                          ThemeMode.light => (Icons.light_mode_rounded, 'Light'),
                        };
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

              // SECTION: SECURITY & ACCESS
              const _SectionHeader(title: 'SECURITY & ACCESS'),
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
                      subtitle: const Text('Update vault master passphrase'),
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
                            : mutedCol,
                      ),
                      title: const Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        authState.isBiometricsAvailable
                            ? (biometricEnabled ? 'Fingerprint unlock enabled' : 'Disabled — tap to enable')
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
                      subtitle: const Text('Lock vault after backgrounding'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            autoLock.label,
                            style: TextStyle(
                              color: mutedCol,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                      onTap: () => openAutoLockDialog(context, ref),
                    ),
                    Divider(height: 1, color: borderCol),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: AppColors.primaryBlue),
                      title: const Text('Screen Privacy', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Block screenshots & cloak task switcher'),
                      trailing: Switch.adaptive(
                        value: screenSecurity,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (val) {
                          ref.read(screenSecurityProvider.notifier).setEnabled(val);
                        },
                      ),
                    ),
                    Divider(height: 1, color: borderCol),
                    ListTile(
                      leading: const Icon(Icons.content_paste_off_rounded, color: AppColors.primaryBlue),
                      title: const Text('Clipboard Auto-Clear', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Auto-wipe secrets after timeout'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            clipboardTimeout.label,
                            style: TextStyle(
                              color: mutedCol,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                      onTap: () => openClipboardTimeoutDialog(context, ref),
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

/// App Info & Maintenance Screen
///
/// Displays application metadata, cryptographic design specs,
/// and houses the irreversible data wipe danger zone.
class AppInfoScreen extends ConsumerWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Info',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SECTION: APPLICATION
              const _SectionHeader(title: 'APPLICATION'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withAlpha(isDark ? 45 : 30),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: AppColors.primaryBlue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VaultX',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Version 1.0.0 (Build 1)',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              color: mutedCol,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: SECURITY ARCHITECTURE
              const _SectionHeader(title: 'SECURITY ARCHITECTURE'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                child: const Column(
                  children: [
                    _CryptoSpecRow(
                      icon: Icons.key_rounded,
                      title: 'Key Derivation',
                      value: 'Argon2id (64 MB, 4 passes)',
                    ),
                    SizedBox(height: 14),
                    _CryptoSpecRow(
                      icon: Icons.lock_rounded,
                      title: 'Symmetric Cipher',
                      value: 'AES-256-GCM Authenticated',
                    ),
                    SizedBox(height: 14),
                    _CryptoSpecRow(
                      icon: Icons.memory_rounded,
                      title: 'Key Storage',
                      value: 'Hardware Secure Enclave / Keystore',
                    ),
                    SizedBox(height: 14),
                    _CryptoSpecRow(
                      icon: Icons.cloud_off_rounded,
                      title: 'Trust Model',
                      value: 'Zero-Knowledge, 100% Offline',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: DANGER ZONE
              const _SectionHeader(title: 'DANGER ZONE'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.rose950.withAlpha(80)
                      : AppColors.rose500.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.rose500.withAlpha(isDark ? 90 : 160),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: isDark ? AppColors.rose400 : const Color(0xFFBE123C),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Wipe All Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.rose400 : const Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Permanently erase all passwords, cards, cryptographic keys, and settings. This action is irreversible.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFFFD1D1) : const Color(0xFF9F1239),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rose500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => confirmWipeData(context, ref),
                        icon: const Icon(Icons.delete_forever_rounded, size: 20),
                        label: const Text(
                          'Wipe Everything',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(isDark ? 45 : 30),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: mutedCol,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: mutedCol,
                  size: 22,
                ),
              ],
            ),
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

class _CryptoSpecRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _CryptoSpecRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: mutedCol, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
