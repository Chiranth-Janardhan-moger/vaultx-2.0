import 'dart:math';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';

/// Detailed offline, zero-knowledge audit report produced by [VaultWatchtowerEngine].
class VaultWatchtowerReport {
  final int totalCredentials;
  final int healthScore; // 0 to 100
  final String healthStatus; // 'Strong', 'Moderate Risk', 'Vulnerable'
  final List<VaultPasswordEntry> reusedEntries;
  final Map<String, int> passwordReuseCount; // password -> count
  final List<VaultPasswordEntry> weakEntries;
  final Map<String, double> weakEntropyMap; // entryId -> entropy bits
  final List<VaultPasswordEntry> missing2faEntries;

  const VaultWatchtowerReport({
    required this.totalCredentials,
    required this.healthScore,
    required this.healthStatus,
    required this.reusedEntries,
    required this.passwordReuseCount,
    required this.weakEntries,
    required this.weakEntropyMap,
    required this.missing2faEntries,
  });

  int get totalIssues =>
      reusedEntries.length + weakEntries.length + missing2faEntries.length;

  bool get hasIssues => totalIssues > 0;
}

/// Offline, zero-knowledge security analyzer for credentials stored in the vault.
///
/// Detects reused passwords across sites, weak passwords (< 50 bits Shannon entropy),
/// and accounts missing RFC 6238 TOTP two-factor authentication.
class VaultWatchtowerEngine {
  VaultWatchtowerEngine._();

  /// Minimum Shannon entropy bits threshold for a password to be considered strong.
  static const double weakEntropyThreshold = 50.0;

  /// Calculates Shannon entropy in bits for a given password:
  /// E = Length * log2(PoolSize)
  static double calculateEntropy(String password) {
    if (password.isEmpty) return 0.0;

    int poolSize = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) poolSize += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) poolSize += 33;

    if (poolSize == 0) poolSize = 10;
    return password.length * (log(poolSize) / ln2);
  }

  /// Audits a list of vault entries and returns an offline [VaultWatchtowerReport].
  static VaultWatchtowerReport audit(List<VaultPasswordEntry> allEntries) {
    // Only analyze active credentials (exclude secure notes and deleted entries)
    final credentials = allEntries
        .where((e) => !e.isDeleted && !e.isSecureNote)
        .toList();

    if (credentials.isEmpty) {
      return const VaultWatchtowerReport(
        totalCredentials: 0,
        healthScore: 100,
        healthStatus: 'Strong',
        reusedEntries: [],
        passwordReuseCount: {},
        weakEntries: [],
        weakEntropyMap: {},
        missing2faEntries: [],
      );
    }

    // 1. Group passwords to detect reuse
    final Map<String, List<VaultPasswordEntry>> passwordGroups = {};
    for (final entry in credentials) {
      final pw = entry.password;
      if (pw.isEmpty) continue;
      passwordGroups.putIfAbsent(pw, () => []).add(entry);
    }

    final List<VaultPasswordEntry> reusedEntries = [];
    final Map<String, int> passwordReuseCount = {};

    for (final entry in credentials) {
      final pw = entry.password;
      final group = passwordGroups[pw];
      if (group != null && group.length > 1) {
        reusedEntries.add(entry);
        passwordReuseCount[pw] = group.length;
      }
    }

    // 2. Identify weak passwords (< 50 bits entropy)
    final List<VaultPasswordEntry> weakEntries = [];
    final Map<String, double> weakEntropyMap = {};

    for (final entry in credentials) {
      final entropy = calculateEntropy(entry.password);
      if (entry.password.isEmpty || entropy < weakEntropyThreshold) {
        weakEntries.add(entry);
        weakEntropyMap[entry.id] = entropy;
      }
    }

    // 3. Identify missing 2FA
    final List<VaultPasswordEntry> missing2faEntries = [];
    for (final entry in credentials) {
      if (!entry.hasTotp) {
        missing2faEntries.add(entry);
      }
    }

    // 4. Calculate Health Score (0 - 100)
    final total = credentials.length;
    final double reusedPenalty = (reusedEntries.length / total) * 40.0;
    final double weakPenalty = (weakEntries.length / total) * 40.0;
    final double missing2faPenalty = (missing2faEntries.length / total) * 20.0;

    final int rawScore = (100.0 - reusedPenalty - weakPenalty - missing2faPenalty)
        .round()
        .clamp(0, 100);

    final String status = rawScore >= 80
        ? 'Strong'
        : rawScore >= 50
            ? 'Moderate Risk'
            : 'Vulnerable';

    return VaultWatchtowerReport(
      totalCredentials: total,
      healthScore: rawScore,
      healthStatus: status,
      reusedEntries: reusedEntries,
      passwordReuseCount: passwordReuseCount,
      weakEntries: weakEntries,
      weakEntropyMap: weakEntropyMap,
      missing2faEntries: missing2faEntries,
    );
  }
}
