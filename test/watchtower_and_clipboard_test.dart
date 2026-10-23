import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/storage/app_settings_storage.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

void main() {
  group('VaultWatchtowerEngine Tests', () {
    test('calculateEntropy returns 0 for empty password', () {
      expect(VaultWatchtowerEngine.calculateEntropy(''), 0.0);
    });

    test('calculateEntropy flags weak passwords under 50 bits', () {
      // 6 lowercase letters: 6 * log2(26) = ~28.2 bits
      final entropyShort = VaultWatchtowerEngine.calculateEntropy('secret');
      expect(entropyShort, lessThan(VaultWatchtowerEngine.weakEntropyThreshold));

      // 8 numeric digits: 8 * log2(10) = ~26.6 bits
      final entropyDigits = VaultWatchtowerEngine.calculateEntropy('12345678');
      expect(entropyDigits, lessThan(VaultWatchtowerEngine.weakEntropyThreshold));
    });

    test('calculateEntropy measures strong passwords over 50 bits', () {
      // 16 chars with mixed upper, lower, numbers, symbols: 16 * log2(95) = ~105 bits
      final entropyStrong = VaultWatchtowerEngine.calculateEntropy('C0mpl3x#P@ssw0rd!99');
      expect(entropyStrong, greaterThan(VaultWatchtowerEngine.weakEntropyThreshold));
    });

    test('audit detects reused passwords across multiple sites', () {
      final now = DateTime.now();
      final entries = [
        VaultPasswordEntry(
          id: '1',
          title: 'Google',
          username: 'user@gmail.com',
          password: 'IdenticalPassword123!',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '2',
          title: 'GitHub',
          username: 'octocat',
          password: 'IdenticalPassword123!',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '3',
          title: 'Bank',
          username: 'bankuser',
          password: 'UniquePassword987!#',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final report = VaultWatchtowerEngine.audit(entries);
      expect(report.totalCredentials, 3);
      expect(report.reusedEntries.length, 2);
      expect(report.passwordReuseCount['IdenticalPassword123!'], 2);
    });

    test('audit detects weak passwords without 2FA penalty', () {
      final now = DateTime.now();
      final entries = [
        VaultPasswordEntry(
          id: '1',
          title: 'WeakAccount',
          username: 'user1',
          password: '123',
          totpSecret: '',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '2',
          title: 'SecureAccount',
          username: 'user2',
          password: r'V3ry$tr0ng&Un1qu3P@ssw0rd999!',
          totpSecret: 'JBSWY3DPEHPK3PXP',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final report = VaultWatchtowerEngine.audit(entries);
      expect(report.weakEntries.length, 1);
      expect(report.weakEntries.first.title, 'WeakAccount');
      expect(report.missing2faEntries.length, 1);
      expect(report.missing2faEntries.first.title, 'WeakAccount');
    });

    test('audit ignores secure notes and deleted entries from credential penalties', () {
      final now = DateTime.now();
      final entries = [
        VaultPasswordEntry(
          id: '1',
          title: 'My Note',
          username: '',
          password: '',
          notes: 'Just a note with sensitive details',
          category: 'Notes',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '2',
          title: 'Old Deleted Account',
          username: 'old',
          password: 'weak',
          isDeleted: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final report = VaultWatchtowerEngine.audit(entries);
      expect(report.totalCredentials, 0);
      expect(report.healthScore, 100);
      expect(report.hasIssues, isFalse);
    });
  });

  group('Favorites & Sorting Tests', () {
    test('VaultPasswordEntry copyWith and serialization preserves isFavorite', () {
      final now = DateTime.now();
      final entry = VaultPasswordEntry(
        id: 'test-1',
        title: 'Work Email',
        username: 'work@co.com',
        password: 'Pass',
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(entry.isFavorite, isTrue);

      final map = entry.toMap();
      expect(map['isFavorite'], isTrue);

      final restored = VaultPasswordEntry.fromMap(map);
      expect(restored.isFavorite, isTrue);

      final toggled = restored.copyWith(isFavorite: false);
      expect(toggled.isFavorite, isFalse);
    });

    test('VaultPasswordsState filters by ★ Favorites category', () {
      final now = DateTime.now();
      final entries = [
        VaultPasswordEntry(
          id: '1',
          title: 'Alpha',
          username: 'a',
          password: 'p1',
          category: 'Work',
          isFavorite: true,
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '2',
          title: 'Beta',
          username: 'b',
          password: 'p2',
          category: 'Social',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final stateAll = VaultPasswordsState(
        allEntries: entries,
        selectedCategory: 'All',
      );
      expect(stateAll.filteredEntries.length, 2);

      final stateFav = VaultPasswordsState(
        allEntries: entries,
        selectedCategory: '★ Favorites',
      );
      expect(stateFav.filteredEntries.length, 1);
      expect(stateFav.filteredEntries.first.title, 'Alpha');
    });

    test('VaultPasswordsState sorts by Alphabetical and pins favorites', () {
      final now = DateTime.now();
      final entries = [
        VaultPasswordEntry(
          id: '1',
          title: 'Zebra',
          username: 'z',
          password: 'pz',
          isFavorite: true, // Should be pinned to top even though title is Z
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '2',
          title: 'Apple',
          username: 'a',
          password: 'pa',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '3',
          title: 'Banana',
          username: 'b',
          password: 'pb',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final state = VaultPasswordsState(
        allEntries: entries,
        activeSortOption: VaultSortOption.alphabetical,
      );

      final sorted = state.filteredEntries;
      expect(sorted[0].title, 'Zebra'); // Pinned favorite
      expect(sorted[1].title, 'Apple');
      expect(sorted[2].title, 'Banana');
    });

    test('VaultPasswordsState sorts by Weakest First strength', () {
      final now = DateTime.now();
      final entries = [
        VaultPasswordEntry(
          id: '1',
          title: 'StrongAccount',
          username: 's',
          password: 'C0mpl3x#P@ssw0rd!99',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: '2',
          title: 'WeakAccount',
          username: 'w',
          password: '123',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final state = VaultPasswordsState(
        allEntries: entries,
        activeSortOption: VaultSortOption.strength,
      );

      final sorted = state.filteredEntries;
      expect(sorted[0].title, 'WeakAccount');
      expect(sorted[1].title, 'StrongAccount');
    });
  });

  group('ClipboardSecurityService & Timeout Preference Tests', () {
    late Directory tempDir;
    late AppSettingsStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vaultx_cb_test_');
      storage = AppSettingsStorage(overrideDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ClipboardTimeout fromId parses correctly with fallback', () {
      expect(ClipboardTimeout.fromId('off'), ClipboardTimeout.off);
      expect(ClipboardTimeout.fromId('30s'), ClipboardTimeout.sec30);
      expect(ClipboardTimeout.fromId('60s'), ClipboardTimeout.sec60);
      expect(ClipboardTimeout.fromId('120s'), ClipboardTimeout.sec120);
      expect(ClipboardTimeout.fromId('unknown'), ClipboardTimeout.sec60);
    });

    test('ClipboardTimeoutNotifier persists and loads setting', () async {
      final notifier = ClipboardTimeoutNotifier(settingsStorage: storage);
      expect(notifier.state, ClipboardTimeout.sec60);

      await notifier.setDuration(ClipboardTimeout.sec30);
      expect(notifier.state, ClipboardTimeout.sec30);

      final reloadedNotifier = ClipboardTimeoutNotifier(settingsStorage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloadedNotifier.state, ClipboardTimeout.sec30);
    });
  });
}
