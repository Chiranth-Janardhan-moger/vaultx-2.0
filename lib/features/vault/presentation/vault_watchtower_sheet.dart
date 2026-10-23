import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';
import 'package:vaultx/features/vault/presentation/edit_password_screen.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/vault/presentation/widgets/concentric_radar_gauge.dart';

/// Modal bottom sheet presenting the offline, zero-knowledge Security Watchtower audit.
class VaultWatchtowerSheet extends ConsumerStatefulWidget {
  const VaultWatchtowerSheet({super.key});

  @override
  ConsumerState<VaultWatchtowerSheet> createState() => _VaultWatchtowerSheetState();
}

class _VaultWatchtowerSheetState extends ConsumerState<VaultWatchtowerSheet> {
  int _selectedFilterIndex = 0; // 0: All, 1: Reused, 2: Weak, 3: Missing 2FA

  void _quickResolveWeakPassword(VaultWatchtowerReport report) {
    if (report.weakEntries.isEmpty) return;
    final weakest = report.weakEntries.first;

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()_+-=';
    final random = math.Random.secure();
    final newPassword = List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();

    final updated = weakest.copyWith(password: newPassword, updatedAt: DateTime.now());
    ref.read(vaultPasswordsProvider.notifier).updatePassword(updated);

    HappyFeedback.celebrate();
    HappyFeedback.show(
      context,
      title: 'Password Fortified',
      message: 'Upgraded "${weakest.title}" with 20-character cryptographic entropy.',
      icon: Icons.shield_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final vaultState = ref.watch(vaultPasswordsProvider);
    final report = VaultWatchtowerEngine.audit(vaultState.allEntries);

    final scoreColor = report.healthScore >= 80
        ? AppColors.emerald500
        : report.healthScore >= 50
            ? AppColors.amber500
            : AppColors.rose500;

    // Filter items based on selected tab
    final List<_AuditIssueItem> issueItems = [];

    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) {
      for (final entry in report.reusedEntries) {
        final count = report.passwordReuseCount[entry.password] ?? 2;
        issueItems.add(_AuditIssueItem(
          entry: entry,
          issueType: _IssueType.reused,
          description: 'Reused across $count credentials',
          badgeColor: AppColors.rose500,
        ));
      }
    }

    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 2) {
      for (final entry in report.weakEntries) {
        final entropy = report.weakEntropyMap[entry.id] ?? 0.0;
        final desc = entry.password.isEmpty
            ? 'Empty password'
            : 'Entropy: ${entropy.toStringAsFixed(1)} bits (< 50 bits)';
        issueItems.add(_AuditIssueItem(
          entry: entry,
          issueType: _IssueType.weak,
          description: desc,
          badgeColor: AppColors.amber500,
        ));
      }
    }

    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 3) {
      for (final entry in report.missing2faEntries) {
        issueItems.add(_AuditIssueItem(
          entry: entry,
          issueType: _IssueType.missing2fa,
          description: 'Account lacks 2FA TOTP authenticator protection',
          badgeColor: const Color(0xFF00F59B),
        ));
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scoreColor.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.security_rounded, color: scoreColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vault Watchtower',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Offline Security Health Audit',
                        style: TextStyle(fontSize: 12, color: mutedCol),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // High-Performance Concentric Radar Health Gauge
          ConcentricRadarGauge(
            report: report,
            selectedFilterIndex: _selectedFilterIndex,
            onFilterSelected: (idx) => setState(() => _selectedFilterIndex = idx),
            onQuickResolveWeak: () => _quickResolveWeakPassword(report),
            onQuickResolveReused: () => setState(() => _selectedFilterIndex = 1),
            onQuickResolve2FA: () => setState(() => _selectedFilterIndex = 3),
          ),
          const SizedBox(height: 14),

          // Metric Category Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  index: 0,
                  label: 'All Issues (${report.totalIssues})',
                  icon: Icons.checklist_rounded,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  index: 1,
                  label: 'Reused (${report.reusedEntries.length})',
                  icon: Icons.copy_rounded,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  highlightColor: report.reusedEntries.isNotEmpty ? AppColors.rose500 : null,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  index: 2,
                  label: 'Weak (${report.weakEntries.length})',
                  icon: Icons.speed_rounded,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  highlightColor: report.weakEntries.isNotEmpty ? AppColors.amber500 : null,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  index: 3,
                  label: 'Missing 2FA (${report.missing2faEntries.length})',
                  icon: Icons.security_rounded,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  highlightColor: report.missing2faEntries.isNotEmpty ? const Color(0xFF00F59B) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Issues List
          Expanded(
            child: issueItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.emerald500.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.emerald500,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Vulnerabilities Found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All credentials in this category meet strict security standards.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: mutedCol),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: issueItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = issueItems[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EditPasswordScreen(entry: item.entry),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Monogram
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: item.badgeColor.withAlpha(isDark ? 35 : 25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      item.entry.title.isNotEmpty
                                          ? item.entry.title.substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: item.badgeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.entry.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: item.badgeColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                item.description,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: item.badgeColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                    // Review Action Button
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withAlpha(isDark ? 40 : 25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Review',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 16,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    Color? highlightColor,
  }) {
    final isSelected = _selectedFilterIndex == index;
    final activeColor = highlightColor ?? AppColors.primaryBlue;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : borderCol,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (highlightColor ?? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _IssueType { reused, weak, missing2fa }

class _AuditIssueItem {
  final VaultPasswordEntry entry;
  final _IssueType issueType;
  final String description;
  final Color badgeColor;

  const _AuditIssueItem({
    required this.entry,
    required this.issueType,
    required this.description,
    required this.badgeColor,
  });
}
