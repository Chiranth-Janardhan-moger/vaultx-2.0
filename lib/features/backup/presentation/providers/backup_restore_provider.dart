import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vaultx/features/backup/domain/vxb_backup_service.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';
import 'package:vaultx/features/wallet/presentation/providers/wallet_cards_provider.dart';

final vxbBackupServiceProvider = Provider<VxbBackupService>((ref) {
  return VxbBackupService();
});

class RestoreReport {
  final int passwordsRestored;
  final int cardsRestored;
  final bool isMerged;

  const RestoreReport({
    required this.passwordsRestored,
    required this.cardsRestored,
    required this.isMerged,
  });
}

class BackupRestoreNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final VxbBackupService _service;

  BackupRestoreNotifier({
    required Ref ref,
    required VxbBackupService service,
  })  : _ref = ref,
        _service = service,
        super(const AsyncValue.data(null));

  /// Exports vault data to a .vxb file and triggers native share/save.
  Future<File> exportBackup({
    required String backupPassword,
    bool shareAfterExport = true,
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      final passwords = _ref.read(vaultPasswordsProvider).allEntries;
      final cards = _ref.read(walletCardsProvider).allCards;

      final backupContent = await _service.exportBackup(
        passwords: passwords,
        cards: cards,
        backupPassword: backupPassword,
      );

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final file = File('${tempDir.path}/vaultx-backup-$timestamp.vxb');
      await file.writeAsString(backupContent);

      if (shareAfterExport) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/octet-stream')],
            subject: 'VaultX Encrypted Backup ($timestamp)',
          ),
        );
      }

      state = const AsyncValue<void>.data(null);
      return file;
    } catch (e, st) {
      state = AsyncValue<void>.error(e, st);
      rethrow;
    }
  }

  /// Inspects and decrypts a .vxb file without applying it to the vault yet.
  Future<VxbBackupPayload> inspectBackup({
    required String filePath,
    required String backupPassword,
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const InvalidBackupFormatException('Backup file not found at the selected path.');
      }

      final content = await file.readAsString();
      final payload = await _service.restoreBackup(
        fileContent: content,
        backupPassword: backupPassword,
      );

      state = const AsyncValue<void>.data(null);
      return payload;
    } catch (e, st) {
      state = AsyncValue<void>.error(e, st);
      rethrow;
    }
  }

  /// Applies the inspected backup payload to the vault.
  Future<RestoreReport> applyRestore({
    required VxbBackupPayload payload,
    required bool replaceExisting,
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      if (replaceExisting) {
        _ref.read(vaultPasswordsProvider.notifier).saveAll(payload.passwords);
        _ref.read(walletCardsProvider.notifier).saveAll(payload.cards);

        final report = RestoreReport(
          passwordsRestored: payload.passwords.length,
          cardsRestored: payload.cards.length,
          isMerged: false,
        );
        state = const AsyncValue<void>.data(null);
        return report;
      }

      // Merge Mode
      final currentPasswords = List<VaultPasswordEntry>.from(
        _ref.read(vaultPasswordsProvider).allEntries,
      );
      int passwordsRestored = 0;

      for (final imported in payload.passwords) {
        final existingIndex = currentPasswords.indexWhere((p) =>
            p.id == imported.id ||
            (p.title.trim().toLowerCase() == imported.title.trim().toLowerCase() &&
                p.username.trim().toLowerCase() == imported.username.trim().toLowerCase()));

        if (existingIndex >= 0) {
          final existing = currentPasswords[existingIndex];
          if (imported.updatedAt.isAfter(existing.updatedAt)) {
            currentPasswords[existingIndex] = imported;
            passwordsRestored++;
          }
        } else {
          currentPasswords.add(imported);
          passwordsRestored++;
        }
      }

      final currentCards = List<WalletCardEntry>.from(
        _ref.read(walletCardsProvider).allCards,
      );
      int cardsRestored = 0;

      for (final imported in payload.cards) {
        final importedCleanNum = imported.cardNumber.replaceAll(RegExp(r'\s+'), '');
        final existingIndex = currentCards.indexWhere((c) =>
            c.id == imported.id ||
            (importedCleanNum.isNotEmpty &&
                c.cardNumber.replaceAll(RegExp(r'\s+'), '') == importedCleanNum));

        if (existingIndex >= 0) {
          final existing = currentCards[existingIndex];
          if (imported.updatedAt.isAfter(existing.updatedAt)) {
            currentCards[existingIndex] = imported;
            cardsRestored++;
          }
        } else {
          currentCards.add(imported);
          cardsRestored++;
        }
      }

      _ref.read(vaultPasswordsProvider.notifier).saveAll(currentPasswords);
      _ref.read(walletCardsProvider.notifier).saveAll(currentCards);

      final report = RestoreReport(
        passwordsRestored: passwordsRestored,
        cardsRestored: cardsRestored,
        isMerged: true,
      );
      state = const AsyncValue<void>.data(null);
      return report;
    } catch (e, st) {
      state = AsyncValue<void>.error(e, st);
      rethrow;
    }
  }
}

final backupRestoreProvider =
    StateNotifierProvider<BackupRestoreNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(vxbBackupServiceProvider);
  return BackupRestoreNotifier(ref: ref, service: service);
});
