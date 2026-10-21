import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';

/// Detailed report of a vault synchronization merge operation.
class VaultMergeReport {
  final int passwordsInserted;
  final int passwordsUpdated;
  final int passwordsDeleted;
  final int passwordsPreservedLocal;
  final int cardsInserted;
  final int cardsUpdated;
  final int cardsDeleted;
  final int cardsPreservedLocal;
  final List<String> detectedConflicts;

  final List<VaultPasswordEntry> mergedPasswords;
  final List<WalletCardEntry> mergedCards;

  const VaultMergeReport({
    required this.passwordsInserted,
    required this.passwordsUpdated,
    this.passwordsDeleted = 0,
    required this.passwordsPreservedLocal,
    required this.cardsInserted,
    required this.cardsUpdated,
    this.cardsDeleted = 0,
    required this.cardsPreservedLocal,
    required this.detectedConflicts,
    required this.mergedPasswords,
    required this.mergedCards,
  });

  int get totalChangesApplied =>
      passwordsInserted + passwordsUpdated + passwordsDeleted + cardsInserted + cardsUpdated + cardsDeleted;
}

/// Conflict-free Merge Engine implementing timestamp-based Last-Write-Wins (LWW)
/// and tombstone-aware missing-entry insertion per §6.2.8.
///
/// Guaranteed properties:
/// 1. Newer local edits are NEVER overwritten by older synced remote edits.
/// 2. Missing entries on either device are seamlessly merged (ignoring deleted tombstones).
/// 3. Deletions propagate via tombstones without resurrecting removed entries.
/// 4. Concurrent conflicting edits are flagged and preserved.
class VaultMergeEngine {
  /// Merges [incomingPasswords] into [localPasswords].
  VaultMergeReport merge({
    required List<VaultPasswordEntry> localPasswords,
    required List<VaultPasswordEntry> incomingPasswords,
    required List<WalletCardEntry> localCards,
    required List<WalletCardEntry> incomingCards,
  }) {
    int pwInserted = 0;
    int pwUpdated = 0;
    int pwDeleted = 0;
    int pwPreserved = 0;
    int cdInserted = 0;
    int cdUpdated = 0;
    int cdDeleted = 0;
    int cdPreserved = 0;
    final conflicts = <String>[];

    // Merge Passwords
    final passwordMap = <String, VaultPasswordEntry>{
      for (final p in localPasswords) p.id: p,
    };

    for (final remote in incomingPasswords) {
      if (!passwordMap.containsKey(remote.id)) {
        if (!remote.isDeleted) {
          // Missing on local -> Add if active
          passwordMap[remote.id] = remote;
          pwInserted++;
        }
      } else {
        final local = passwordMap[remote.id]!;
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          // Remote is strictly newer -> Update / Apply tombstone
          passwordMap[remote.id] = remote;
          if (remote.isDeleted && !local.isDeleted) {
            pwDeleted++;
          } else {
            pwUpdated++;
          }
        } else if (local.updatedAt.isAfter(remote.updatedAt)) {
          // Local is strictly newer -> Preserve local
          pwPreserved++;
        } else {
          // Same timestamp -> Check for content divergence
          if (local.password != remote.password ||
              local.username != remote.username ||
              local.title != remote.title ||
              local.isDeleted != remote.isDeleted) {
            conflicts.add(
              'Password conflict on "${local.title}": identical timestamp with different data.',
            );
            // Preserve local as authoritative in tie
            pwPreserved++;
          }
        }
      }
    }

    // Merge Cards
    final cardMap = <String, WalletCardEntry>{
      for (final c in localCards) c.id: c,
    };

    for (final remote in incomingCards) {
      if (!cardMap.containsKey(remote.id)) {
        if (!remote.isDeleted) {
          // Missing on local -> Add if active
          cardMap[remote.id] = remote;
          cdInserted++;
        }
      } else {
        final local = cardMap[remote.id]!;
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          // Remote is strictly newer -> Update / Apply tombstone
          cardMap[remote.id] = remote;
          if (remote.isDeleted && !local.isDeleted) {
            cdDeleted++;
          } else {
            cdUpdated++;
          }
        } else if (local.updatedAt.isAfter(remote.updatedAt)) {
          // Local is strictly newer -> Preserve local
          cdPreserved++;
        } else {
          // Same timestamp
          if (local.cardNumber != remote.cardNumber ||
              local.cvv != remote.cvv ||
              local.title != remote.title ||
              local.isDeleted != remote.isDeleted) {
            conflicts.add(
              'Card conflict on "${local.title}": identical timestamp with different data.',
            );
            cdPreserved++;
          }
        }
      }
    }

    return VaultMergeReport(
      passwordsInserted: pwInserted,
      passwordsUpdated: pwUpdated,
      passwordsDeleted: pwDeleted,
      passwordsPreservedLocal: pwPreserved,
      cardsInserted: cdInserted,
      cardsUpdated: cdUpdated,
      cardsDeleted: cdDeleted,
      cardsPreservedLocal: cdPreserved,
      detectedConflicts: conflicts,
      mergedPasswords: passwordMap.values.where((p) => !p.isDeleted).toList(),
      mergedCards: cardMap.values.where((c) => !c.isDeleted).toList(),
    );
  }
}
