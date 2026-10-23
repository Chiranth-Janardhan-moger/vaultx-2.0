import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/features/backup/domain/vxb_backup_service.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';
import 'package:vaultx/features/vault/presentation/add_password_screen.dart';
import 'package:vaultx/features/vault/presentation/edit_password_screen.dart';
import 'package:vaultx/features/vault/presentation/passwords_vault_screen.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  final now = DateTime(2026, 10, 23, 12, 0, 0);

  group('VaultPasswordEntry PIN Model Tests', () {
    test('Default values for PIN and password fields', () {
      final entry = VaultPasswordEntry(
        id: 'pin-1',
        title: 'HDFC ATM PIN',
        username: '',
        createdAt: now,
        updatedAt: now,
      );

      expect(entry.password, '');
      expect(entry.pin, '');
      expect(entry.transactionPin, '');
      expect(entry.hasPin, false);
      expect(entry.isPinOnly, false);
    });

    test('hasPin returns true when pin or transactionPin is present', () {
      final atmEntry = VaultPasswordEntry(
        id: 'pin-2',
        title: 'Debit Card PIN',
        username: '',
        pin: '4829',
        createdAt: now,
        updatedAt: now,
      );
      expect(atmEntry.hasPin, true);

      final upiEntry = VaultPasswordEntry(
        id: 'pin-3',
        title: 'Google Pay UPI',
        username: '',
        transactionPin: '918273',
        createdAt: now,
        updatedAt: now,
      );
      expect(upiEntry.hasPin, true);
    });

    test('isPinOnly evaluates correctly for pure PIN and categorized entries', () {
      final purePin = VaultPasswordEntry(
        id: 'pin-4',
        title: 'SBI ATM',
        username: '',
        password: '',
        pin: '1234',
        category: 'Banking',
        createdAt: now,
        updatedAt: now,
      );
      expect(purePin.isPinOnly, true);

      final categorizedPin = VaultPasswordEntry(
        id: 'pin-5',
        title: 'Card Code',
        username: 'user',
        password: 'somePassword',
        pin: '1234',
        category: 'PINs',
        createdAt: now,
        updatedAt: now,
      );
      expect(categorizedPin.isPinOnly, true);

      final standardLogin = VaultPasswordEntry(
        id: 'pin-6',
        title: 'GitHub',
        username: 'octocat',
        password: 'SecurePassword123!',
        pin: '',
        category: 'Work',
        createdAt: now,
        updatedAt: now,
      );
      expect(standardLogin.isPinOnly, false);
    });

    test('isSecureNote does not falsely match entries that have PINs', () {
      final pinEntry = VaultPasswordEntry(
        id: 'pin-7',
        title: 'ATM Secret',
        username: '',
        password: '',
        pin: '7721',
        notes: 'Backup recovery code',
        category: 'Banking',
        createdAt: now,
        updatedAt: now,
      );

      expect(pinEntry.hasPin, true);
      expect(pinEntry.isSecureNote, false);
    });

    test('copyWith properly preserves or updates PIN fields', () {
      final original = VaultPasswordEntry(
        id: 'pin-8',
        title: 'Axis Bank PIN',
        username: '',
        pin: '1122',
        transactionPin: '3344',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(pin: '9988');
      expect(updated.pin, '9988');
      expect(updated.transactionPin, '3344');
      expect(updated.title, 'Axis Bank PIN');
    });

    test('toMap and fromMap serialize and deserialize PIN fields', () {
      final entry = VaultPasswordEntry(
        id: 'pin-9',
        title: 'ICICI Bank Card',
        username: 'chiranth',
        email: 'chiranth@example.com',
        password: 'MasterPassword!',
        pin: '5678',
        transactionPin: '876543',
        category: 'Banking',
        createdAt: now,
        updatedAt: now,
      );

      final map = entry.toMap();
      expect(map['pin'], '5678');
      expect(map['transactionPin'], '876543');

      final restored = VaultPasswordEntry.fromMap(map);
      expect(restored.id, entry.id);
      expect(restored.pin, '5678');
      expect(restored.transactionPin, '876543');
      expect(restored.password, 'MasterPassword!');
    });

    test('toJson and fromJson round-trip accurately', () {
      final entry = VaultPasswordEntry(
        id: 'pin-10',
        title: 'Union Bank ATM',
        username: '',
        pin: '4321',
        category: 'PINs',
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = entry.toJson();
      final restored = VaultPasswordEntry.fromJson(jsonStr);

      expect(restored.title, 'Union Bank ATM');
      expect(restored.pin, '4321');
      expect(restored.isPinOnly, true);
    });
  });

  group('VxbBackupService PIN Serialization Tests', () {
    test('Export and restore backup preserves PIN and transaction PIN', () async {
      final backupService = VxbBackupService();
      final originalEntries = [
        VaultPasswordEntry(
          id: 'vxb-pin-1',
          title: 'HDFC Debit PIN',
          username: '',
          pin: '9876',
          transactionPin: '123456',
          category: 'Banking',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: 'vxb-login-1',
          title: 'ProtonMail',
          username: 'user@pm.me',
          password: 'SecretPassword987!',
          category: 'Others',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      const backupPassword = 'StrongBackupPassword2026!';
      final encryptedVxb = await backupService.exportBackup(
        passwords: originalEntries,
        cards: const [],
        backupPassword: backupPassword,
      );

      expect(encryptedVxb.isNotEmpty, true);

      final restoredPayload = await backupService.restoreBackup(
        fileContent: encryptedVxb,
        backupPassword: backupPassword,
      );

      expect(restoredPayload.passwords.length, 2);

      final restoredPinEntry = restoredPayload.passwords.firstWhere(
        (p) => p.title == 'HDFC Debit PIN',
      );
      expect(restoredPinEntry.pin, '9876');
      expect(restoredPinEntry.transactionPin, '123456');

      final restoredLogin = restoredPayload.passwords.firstWhere(
        (p) => p.title == 'ProtonMail',
      );
      expect(restoredLogin.password, 'SecretPassword987!');
      expect(restoredLogin.pin, '');
    });
  });

  group('VaultWatchtowerEngine PIN Immunity Tests', () {
    test('PIN-only entries are excluded from audit and never flag weak warnings', () {
      final pinEntries = [
        VaultPasswordEntry(
          id: 'pin-w1',
          title: 'ATM Card PIN',
          username: '',
          password: '',
          pin: '1234', // 4 numeric digits would have low entropy if treated as password
          category: 'Banking',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: 'pin-w2',
          title: 'UPI PIN',
          username: '',
          password: '',
          transactionPin: '9988',
          category: 'PINs',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final report = VaultWatchtowerEngine.audit(pinEntries);

      // PIN-only entries are completely immune from password weakness warnings
      expect(report.totalCredentials, 0);
      expect(report.weakEntries.isEmpty, true);
      expect(report.reusedEntries.isEmpty, true);
      expect(report.healthScore, 100);
      expect(report.healthStatus, 'Strong');
    });

    test('Hybrid credentials with password and PIN have password analyzed', () {
      final hybridEntries = [
        VaultPasswordEntry(
          id: 'hybrid-1',
          title: 'Chase Banking',
          username: 'chaseuser',
          password: '123', // Weak password
          pin: '4321', // ATM PIN
          category: 'Banking',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final report = VaultWatchtowerEngine.audit(hybridEntries);

      // Password was weak, so it is analyzed
      expect(report.totalCredentials, 1);
      expect(report.weakEntries.length, 1);
      expect(report.healthScore, lessThan(100));
    });
  });

  group('VaultPasswordsProvider PIN Category & Sorting Tests', () {
    test('PINs is present in defaultCategories and entryCategories', () {
      expect(VaultPasswordsState.defaultCategories.contains('PINs'), true);
      expect(VaultPasswordsState.entryCategories.contains('PINs'), true);
    });

    test('getCategoryColor returns emerald 0xFF10B981 for PINs', () {
      expect(getCategoryColor('PINs'), const Color(0xFF10B981));
      expect(getCategoryColor('pins'), const Color(0xFF10B981));
      expect(getCategoryColor('pin'), const Color(0xFF10B981));
    });

    test('filteredEntries smart matches entries with PINs when PINs category selected', () {
      final entries = [
        VaultPasswordEntry(
          id: 'f-1',
          title: 'HDFC Bank',
          username: 'hdfc_user',
          password: '',
          pin: '1122',
          category: 'Banking', // Categorized as Banking, but has PIN
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: 'f-2',
          title: 'Google Pay',
          username: '',
          password: '',
          transactionPin: '5566',
          category: 'Others', // Has transaction PIN
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: 'f-3',
          title: 'Reddit Login',
          username: 'redditor',
          password: 'Password999!',
          category: 'Social',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: 'f-4',
          title: 'Locker PIN',
          username: '',
          password: '',
          pin: '9090',
          category: 'PINs',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final state = VaultPasswordsState(
        allEntries: entries,
        selectedCategory: 'PINs',
      );

      final filtered = state.filteredEntries;
      expect(filtered.length, 3);
      expect(filtered.any((e) => e.title == 'HDFC Bank'), true);
      expect(filtered.any((e) => e.title == 'Google Pay'), true);
      expect(filtered.any((e) => e.title == 'Locker PIN'), true);
      expect(filtered.any((e) => e.title == 'Reddit Login'), false);
    });

    test('strength sort gives 999.0 entropy to isPinOnly entries', () {
      final entries = [
        VaultPasswordEntry(
          id: 's-1',
          title: 'Weak Password Site',
          username: 'user1',
          password: 'abc', // Very weak
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: 's-2',
          title: 'SBI ATM PIN',
          username: '',
          password: '',
          pin: '1234',
          category: 'PINs',
          createdAt: now,
          updatedAt: now,
        ),
        VaultPasswordEntry(
          id: 's-3',
          title: 'Strong Password Site',
          username: 'user2',
          password: 'SuperDuper#Strong#Password2026!',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final state = VaultPasswordsState(
        allEntries: entries,
        activeSortOption: VaultSortOption.strength,
      );

      final sorted = state.filteredEntries;
      // Weakest first: 'Weak Password Site' comes first
      expect(sorted.first.title, 'Weak Password Site');
      // PIN entry is treated as 999.0 entropy (top strength), so it is not listed as weakest
      expect(sorted.last.title, 'SBI ATM PIN');
    });
  });

  group('ScrambledPinKeypad Widget Tests', () {
    testWidgets('ScrambledPinKeypad renders header, digits, and test display', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ScrambledPinKeypad(
            title: 'ATM PIN',
            pin: '1234',
          ),
        ),
      );

      expect(find.text('ATM PIN Keypad'), findsOneWidget);
      expect(find.text('Scrambled Anti-Surveillance Keypad'), findsOneWidget);
      expect(find.text('CLR'), findsOneWidget);
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);

      // Verify digits 0 through 9 are present on the keypad
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('Tapping digits inputs PIN and verifies match', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ScrambledPinKeypad(
            title: 'ATM PIN',
            pin: '5820',
          ),
        ),
      );

      // Tap 5, 8, 2, 0
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      // Masked dots should be displayed (4 dots)
      expect(find.text('● ● ● ●'), findsOneWidget);
      expect(find.text('PIN Verified Match'), findsOneWidget);

      // Tap CLR to clear
      await tester.tap(find.text('CLR'));
      await tester.pump();

      expect(find.text('Tap scrambled digits to test'), findsOneWidget);
    });

    testWidgets('Reshuffle button reshuffles keypad digits', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ScrambledPinKeypad(
            title: 'UPI PIN',
            pin: '9988',
          ),
        ),
      );

      // Tap reshuffle
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      await tester.pump();

      // Digits 0 through 9 are still all present
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });
  });

  group('Add & Edit Screen PIN Input Tests', () {
    testWidgets('AddPasswordScreen contains ATM PIN and UPI PIN fields', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const AddPasswordScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bank / ATM PIN'), findsOneWidget);
      expect(find.text('UPI / Transaction PIN'), findsOneWidget);
    });

    testWidgets('EditPasswordScreen displays existing PINs and allows modification', (tester) async {
      final existingEntry = VaultPasswordEntry(
        id: 'edit-pin-1',
        title: 'HDFC Bank Card',
        username: 'user1',
        password: '',
        pin: '4321',
        transactionPin: '8877',
        category: 'Banking',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _buildTestApp(EditPasswordScreen(entry: existingEntry)),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATM PIN'), findsOneWidget);
      expect(find.text('UPI PIN'), findsOneWidget);
      expect(find.text('4321'), findsOneWidget);
      expect(find.text('8877'), findsOneWidget);
    });
  });

  group('PasswordsVaultScreen Credential Inspection Sheet PIN Tests', () {
    testWidgets('Inspection sheet displays tactile masked dots, unmask toggle, and keypad button', (tester) async {
      final pinEntry = VaultPasswordEntry(
        id: 'inspect-pin-1',
        title: 'Axis Debit Card',
        username: '',
        password: '',
        pin: '2468',
        transactionPin: '1357',
        category: 'Banking',
        createdAt: now,
        updatedAt: now,
      );

      final notifier = VaultPasswordsNotifier();
      notifier.addPassword(pinEntry);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultPasswordsProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: PasswordsVaultScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the card in the vault list to open inspection sheet
      expect(find.text('Axis Debit Card'), findsOneWidget);
      await tester.tap(find.text('Axis Debit Card'));
      await tester.pumpAndSettle();

      // Inspection sheet should be visible with ATM PIN and UPI PIN rows
      expect(find.text('ATM / Bank PIN'), findsOneWidget);
      expect(find.text('UPI / Transaction PIN'), findsOneWidget);

      // Tactile masked dots should be displayed (● ● ● ●)
      expect(find.text('● ● ● ●'), findsNWidgets(2));

      // Keypad icon buttons should be present
      expect(find.byIcon(Icons.dialpad_rounded), findsWidgets);

      // Tap the first Keypad button to open ScrambledPinKeypad
      await tester.tap(find.byIcon(Icons.dialpad_rounded).first);
      await tester.pumpAndSettle();

      // ScrambledPinKeypad sheet is now open
      expect(find.text('ATM PIN Keypad'), findsOneWidget);
      expect(find.text('Scrambled Anti-Surveillance Keypad'), findsOneWidget);
    });
  });
}
