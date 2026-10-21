import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/storage/app_settings_storage.dart';
import 'package:vaultx/core/storage/vault_storage_service.dart';
import 'package:vaultx/features/settings/presentation/providers/auto_lock_provider.dart';
import 'package:vaultx/features/settings/presentation/providers/biometric_preference_provider.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';

void main() {
  late Directory tempDir;
  late List<int> masterKeyA;
  late List<int> masterKeyB;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vaultx_test_');
    masterKeyA = List<int>.generate(32, (i) => i + 1);
    masterKeyB = List<int>.generate(32, (i) => (i + 1) * 2 % 256);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VaultStorageService Encrypted Persistence Tests', () {
    test('Round-trip saves, encrypts, and decrypts passwords across restarts', () async {
      final storage1 = VaultStorageService(overrideDir: tempDir);

      final entry1 = VaultPasswordEntry(
        id: 'pass_001',
        title: 'Google Account',
        username: 'user@gmail.com',
        email: 'user@gmail.com',
        password: 'SuperSecretPassword123!',
        category: 'Email',
        websiteUrl: 'https://google.com',
        notes: 'Primary personal account',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final entry2 = VaultPasswordEntry(
        id: 'pass_002',
        title: 'GitHub',
        username: 'octocat',
        email: 'dev@github.com',
        password: 'GithubToken987654',
        category: 'GitHub',
        websiteUrl: 'https://github.com',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage1.savePassword(entry1, masterKeyA);
      await storage1.savePassword(entry2, masterKeyA);

      // Verify file exists on disk and DOES NOT contain plaintext passwords
      final file = File('${tempDir.path}/vaultx_passwords.enc');
      expect(await file.exists(), isTrue);
      final rawContent = await file.readAsString();
      expect(rawContent.contains('SuperSecretPassword123!'), isFalse);
      expect(rawContent.contains('GithubToken987654'), isFalse);
      expect(rawContent.contains('Google Account'), isFalse);

      // Simulate app restart with a fresh storage instance
      final storage2 = VaultStorageService(overrideDir: tempDir);
      final loaded = await storage2.loadPasswords(masterKeyA);

      expect(loaded.length, equals(2));
      final loadedGoogle = loaded.firstWhere((e) => e.id == 'pass_001');
      expect(loadedGoogle.title, equals('Google Account'));
      expect(loadedGoogle.username, equals('user@gmail.com'));
      expect(loadedGoogle.password, equals('SuperSecretPassword123!'));

      final loadedGithub = loaded.firstWhere((e) => e.id == 'pass_002');
      expect(loadedGithub.title, equals('GitHub'));
      expect(loadedGithub.password, equals('GithubToken987654'));
    });

    test('Wrong master key cannot decrypt vault passwords', () async {
      final storage = VaultStorageService(overrideDir: tempDir);

      final entry = VaultPasswordEntry(
        id: 'pass_secret',
        title: 'Bank Vault',
        username: 'admin',
        password: 'BankingPassword999',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.savePassword(entry, masterKeyA);

      // Loading with wrong key returns empty/safely skips tampered/unauthenticated records
      final loadedWithWrongKey = await storage.loadPasswords(masterKeyB);
      expect(loadedWithWrongKey.isEmpty, isTrue);
    });

    test('Round-trip saves, encrypts, and decrypts cards across restarts', () async {
      final storage1 = VaultStorageService(overrideDir: tempDir);

      final card1 = WalletCardEntry(
        id: 'card_001',
        title: 'Sapphire Preferred',
        cardholderName: 'Jane Doe',
        cardNumber: '4111222233334444',
        expiry: '12/28',
        cvv: '123',
        network: 'Visa',
        cardTheme: 'chase_sapphire',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage1.saveCard(card1, masterKeyA);

      // Verify file exists on disk and DOES NOT contain plaintext card number or CVV
      final file = File('${tempDir.path}/vaultx_cards.enc');
      expect(await file.exists(), isTrue);
      final rawContent = await file.readAsString();
      expect(rawContent.contains('4111222233334444'), isFalse);
      expect(rawContent.contains('123'), isFalse);

      // Fresh instance restart
      final storage2 = VaultStorageService(overrideDir: tempDir);
      final loaded = await storage2.loadCards(masterKeyA);

      expect(loaded.length, equals(1));
      expect(loaded.first.title, equals('Sapphire Preferred'));
      expect(loaded.first.cardNumber, equals('4111222233334444'));
      expect(loaded.first.cvv, equals('123'));
    });

    test('Delete removes encrypted entry from disk', () async {
      final storage = VaultStorageService(overrideDir: tempDir);

      final entry1 = VaultPasswordEntry(
        id: 'pass_del_1',
        title: 'Temporary Service',
        username: 'user1',
        password: 'pass1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.savePassword(entry1, masterKeyA);
      var loaded = await storage.loadPasswords(masterKeyA);
      expect(loaded.length, equals(1));

      await storage.deletePassword('pass_del_1');
      loaded = await storage.loadPasswords(masterKeyA);
      expect(loaded.isEmpty, isTrue);
    });

    test('Re-encrypts all passwords and cards when changing master password', () async {
      final storage = VaultStorageService(overrideDir: tempDir);

      final entry = VaultPasswordEntry(
        id: 'pass_rekey',
        title: 'Critical Service',
        username: 'admin',
        password: 'PassRekey123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final card = WalletCardEntry(
        id: 'card_rekey',
        title: 'Main Debit',
        cardholderName: 'Jane',
        cardNumber: '5555444433332222',
        expiry: '05/27',
        cvv: '456',
        network: 'Mastercard',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.savePassword(entry, masterKeyA);
      await storage.saveCard(card, masterKeyA);

      // Re-encrypt from masterKeyA to masterKeyB
      await storage.reEncryptAll(oldMasterKey: masterKeyA, newMasterKey: masterKeyB);

      // Verify decryptable with masterKeyB
      final passwordsWithB = await storage.loadPasswords(masterKeyB);
      expect(passwordsWithB.length, equals(1));
      expect(passwordsWithB.first.password, equals('PassRekey123'));

      final cardsWithB = await storage.loadCards(masterKeyB);
      expect(cardsWithB.length, equals(1));
      expect(cardsWithB.first.cardNumber, equals('5555444433332222'));

      // Verify no longer decryptable with old masterKeyA
      final passwordsWithA = await storage.loadPasswords(masterKeyA);
      expect(passwordsWithA.isEmpty, isTrue);
    });

    test('Wipe removes all files from disk', () async {
      final storage = VaultStorageService(overrideDir: tempDir);

      final entry = VaultPasswordEntry(
        id: 'pass_wipe',
        title: 'Test',
        username: 'u',
        password: 'p',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.savePassword(entry, masterKeyA);
      expect(await File('${tempDir.path}/vaultx_passwords.enc').exists(), isTrue);

      await storage.wipeAll();
      expect(await File('${tempDir.path}/vaultx_passwords.enc').exists(), isFalse);
      expect(await File('${tempDir.path}/vaultx_cards.enc').exists(), isFalse);
    });
  });

  group('AppSettingsStorage & Preference Providers Tests', () {
    test('AppSettingsStorage persists and loads settings across restarts', () async {
      final settings1 = AppSettingsStorage(overrideDir: tempDir);
      await settings1.writeSetting('vaultx_auto_lock_duration', '1min');
      await settings1.writeSetting('vaultx_biometric_enabled', true);
      await settings1.writeSetting('vaultx_theme_mode', 'dark');

      final settings2 = AppSettingsStorage(overrideDir: tempDir);
      final loaded = await settings2.readSettings();

      expect(loaded['vaultx_auto_lock_duration'], equals('1min'));
      expect(loaded['vaultx_biometric_enabled'], equals(true));
      expect(loaded['vaultx_theme_mode'], equals('dark'));
    });

    test('AutoLockNotifier persists and restores configured duration', () async {
      final settings = AppSettingsStorage(overrideDir: tempDir);
      final notifier1 = AutoLockNotifier(settingsStorage: settings);

      // Default duration is 5min
      expect(notifier1.state, equals(AutoLockDuration.min5));

      // User changes duration to 1min
      await notifier1.setDuration(AutoLockDuration.min1);
      expect(notifier1.state, equals(AutoLockDuration.min1));

      // App reopens: fresh notifier restores 1min
      final notifier2 = AutoLockNotifier(settingsStorage: settings);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier2.state, equals(AutoLockDuration.min1));
    });

    test('BiometricPreferenceNotifier persists disable and enable state', () async {
      final settings = AppSettingsStorage(overrideDir: tempDir);
      final notifier1 = BiometricPreferenceNotifier(settingsStorage: settings);

      // User explicitly disables biometrics
      await notifier1.disable();
      expect(notifier1.state, isFalse);

      // App reopens: verifies it remains disabled
      final notifier2 = BiometricPreferenceNotifier(settingsStorage: settings);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier2.state, isFalse);

      // Directly write enabled in settings to simulate successful scan
      await settings.writeSetting('vaultx_biometric_enabled', true);

      // App reopens: verifies enabled state is restored
      final notifier3 = BiometricPreferenceNotifier(settingsStorage: settings);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier3.state, isTrue);
    });
  });
}
