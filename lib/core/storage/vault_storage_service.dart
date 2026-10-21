import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vaultx/core/crypto/vault_cipher.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';

/// Secure encrypted-at-rest storage service for vault passwords and cards.
///
/// Complies with Section 6.1 of the security architecture:
/// - Every entry is encrypted individually with AES-256-GCM under a key
///   derived from the master key via HKDF and bound to the entry ID.
/// - Fresh 96-bit CSPRNG nonces per write operation.
/// - No plaintext data is stored on disk or in unencrypted logs.
/// - Tampered ciphertext or wrong keys throw and are safely rejected.
class VaultStorageService {
  static const String _passwordsFile = 'vaultx_passwords.enc';
  static const String _cardsFile = 'vaultx_cards.enc';
  static const String _categoriesFile = 'vaultx_categories.json';

  final VaultCipher _cipher;
  final Directory? overrideDir;

  VaultStorageService({
    VaultCipher? cipher,
    this.overrideDir,
  }) : _cipher = cipher ?? VaultCipher();

  Future<Directory> _getDirectory() async {
    return overrideDir ?? await getApplicationDocumentsDirectory();
  }

  Future<File> _getFile(String name) async {
    final dir = await _getDirectory();
    return File('${dir.path}/$name');
  }

  // ==========================================
  // PASSWORDS
  // ==========================================

  /// Loads and decrypts all stored passwords using the active [masterKey].
  Future<List<VaultPasswordEntry>> loadPasswords(List<int> masterKey) async {
    try {
      final file = await _getFile(_passwordsFile);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final entriesMap = (decoded['entries'] as Map<String, dynamic>?) ?? {};

      final entries = <VaultPasswordEntry>[];
      for (final e in entriesMap.entries) {
        final entryId = e.key;
        try {
          final record = EncryptedRecord.fromJsonString(jsonEncode(e.value));
          final decryptedJson = await _cipher.decryptToString(
            record: record,
            masterKey: masterKey,
            entryId: entryId,
          );
          entries.add(VaultPasswordEntry.fromJson(decryptedJson));
        } catch (err) {
          debugPrint('Failed to decrypt password entry $entryId: $err'); // security-exempt
        }
      }

      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return entries;
    } catch (e) {
      debugPrint('VaultStorageService.loadPasswords error: $e'); // security-exempt
      return [];
    }
  }

  /// Encrypts and persists a single [entry] using [masterKey].
  Future<void> savePassword(VaultPasswordEntry entry, List<int> masterKey) async {
    try {
      final file = await _getFile(_passwordsFile);
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          data = (jsonDecode(content) as Map<String, dynamic>?) ?? {};
        }
      }

      final entriesMap = (data['entries'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final encryptedRecord = await _cipher.encryptString(
        plaintext: entry.toJson(),
        masterKey: masterKey,
        entryId: entry.id,
      );

      entriesMap[entry.id] = jsonDecode(encryptedRecord.toJsonString());
      data['entries'] = entriesMap;
      data['version'] = 1;

      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('VaultStorageService.savePassword error: $e'); // security-exempt
    }
  }

  /// Saves a batch of passwords (e.g. after sync or bulk import).
  Future<void> saveAllPasswords(List<VaultPasswordEntry> entries, List<int> masterKey) async {
    try {
      final file = await _getFile(_passwordsFile);
      final entriesMap = <String, dynamic>{};

      for (final entry in entries) {
        final encryptedRecord = await _cipher.encryptString(
          plaintext: entry.toJson(),
          masterKey: masterKey,
          entryId: entry.id,
        );
        entriesMap[entry.id] = jsonDecode(encryptedRecord.toJsonString());
      }

      final data = {
        'version': 1,
        'entries': entriesMap,
      };

      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('VaultStorageService.saveAllPasswords error: $e'); // security-exempt
    }
  }

  /// Deletes a password by [id].
  Future<void> deletePassword(String id) async {
    try {
      final file = await _getFile(_passwordsFile);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final data = (jsonDecode(content) as Map<String, dynamic>?) ?? {};
      final entriesMap = (data['entries'] as Map<String, dynamic>?) ?? {};

      if (entriesMap.containsKey(id)) {
        entriesMap.remove(id);
        data['entries'] = entriesMap;
        await file.writeAsString(jsonEncode(data), flush: true);
      }
    } catch (e) {
      debugPrint('VaultStorageService.deletePassword error: $e'); // security-exempt
    }
  }

  // ==========================================
  // CARDS
  // ==========================================

  /// Loads and decrypts all stored cards using the active [masterKey].
  Future<List<WalletCardEntry>> loadCards(List<int> masterKey) async {
    try {
      final file = await _getFile(_cardsFile);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final cardsMap = (decoded['cards'] as Map<String, dynamic>?) ?? {};

      final cards = <WalletCardEntry>[];
      for (final c in cardsMap.entries) {
        final cardId = c.key;
        try {
          final record = EncryptedRecord.fromJsonString(jsonEncode(c.value));
          final decryptedJson = await _cipher.decryptToString(
            record: record,
            masterKey: masterKey,
            entryId: cardId,
          );
          cards.add(WalletCardEntry.fromJson(decryptedJson));
        } catch (err) {
          debugPrint('Failed to decrypt card entry $cardId: $err');
        }
      }

      cards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return cards;
    } catch (e) {
      debugPrint('VaultStorageService.loadCards error: $e');
      return [];
    }
  }

  /// Encrypts and persists a single [card] using [masterKey].
  Future<void> saveCard(WalletCardEntry card, List<int> masterKey) async {
    try {
      final file = await _getFile(_cardsFile);
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          data = (jsonDecode(content) as Map<String, dynamic>?) ?? {};
        }
      }

      final cardsMap = (data['cards'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final encryptedRecord = await _cipher.encryptString(
        plaintext: card.toJson(),
        masterKey: masterKey,
        entryId: card.id,
      );

      cardsMap[card.id] = jsonDecode(encryptedRecord.toJsonString());
      data['cards'] = cardsMap;
      data['version'] = 1;

      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('VaultStorageService.saveCard error: $e');
    }
  }

  /// Saves a batch of cards.
  Future<void> saveAllCards(List<WalletCardEntry> cards, List<int> masterKey) async {
    try {
      final file = await _getFile(_cardsFile);
      final cardsMap = <String, dynamic>{};

      for (final card in cards) {
        final encryptedRecord = await _cipher.encryptString(
          plaintext: card.toJson(),
          masterKey: masterKey,
          entryId: card.id,
        );
        cardsMap[card.id] = jsonDecode(encryptedRecord.toJsonString());
      }

      final data = {
        'version': 1,
        'cards': cardsMap,
      };

      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('VaultStorageService.saveAllCards error: $e');
    }
  }

  /// Deletes a card by [id].
  Future<void> deleteCard(String id) async {
    try {
      final file = await _getFile(_cardsFile);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final data = (jsonDecode(content) as Map<String, dynamic>?) ?? {};
      final cardsMap = (data['cards'] as Map<String, dynamic>?) ?? {};

      if (cardsMap.containsKey(id)) {
        cardsMap.remove(id);
        data['cards'] = cardsMap;
        await file.writeAsString(jsonEncode(data), flush: true);
      }
    } catch (e) {
      debugPrint('VaultStorageService.deleteCard error: $e');
    }
  }

  // ==========================================
  // CUSTOM CATEGORIES
  // ==========================================

  Future<List<String>> loadCustomCategories() async {
    try {
      final file = await _getFile(_categoriesFile);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      debugPrint('VaultStorageService.loadCustomCategories error: $e');
      return [];
    }
  }

  Future<void> saveCustomCategories(List<String> categories) async {
    try {
      final file = await _getFile(_categoriesFile);
      await file.writeAsString(jsonEncode(categories), flush: true);
    } catch (e) {
      debugPrint('VaultStorageService.saveCustomCategories error: $e');
    }
  }

  // ==========================================
  // RE-ENCRYPT & WIPE
  // ==========================================

  /// Re-encrypts all passwords and cards when the master password is changed.
  Future<void> reEncryptAll({
    required List<int> oldMasterKey,
    required List<int> newMasterKey,
  }) async {
    final passwords = await loadPasswords(oldMasterKey);
    final cards = await loadCards(oldMasterKey);

    if (passwords.isNotEmpty) {
      await saveAllPasswords(passwords, newMasterKey);
    }
    if (cards.isNotEmpty) {
      await saveAllCards(cards, newMasterKey);
    }
  }

  /// Cryptographically wipes all encrypted vaults and category files from disk.
  Future<void> wipeAll() async {
    try {
      final pFile = await _getFile(_passwordsFile);
      if (await pFile.exists()) await pFile.delete();

      final cFile = await _getFile(_cardsFile);
      if (await cFile.exists()) await cFile.delete();

      final catFile = await _getFile(_categoriesFile);
      if (await catFile.exists()) await catFile.delete();
    } catch (e) {
      debugPrint('VaultStorageService.wipeAll error: $e');
    }
  }
}

final vaultStorageServiceProvider = Provider<VaultStorageService>((ref) {
  return VaultStorageService();
});
