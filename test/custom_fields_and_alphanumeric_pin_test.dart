import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/character_indexer_chips.dart';
import 'package:vaultx/features/backup/domain/vxb_backup_service.dart';
import 'package:vaultx/features/desktop/presentation/widgets/desktop_credential_detail_pane.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
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
  final now = DateTime(2026, 10, 23, 14, 0, 0);

  group('VaultCustomField & Alphanumeric PIN Domain Tests', () {
    test('VaultCustomField equality and serialization roundtrip', () {
      const field1 = VaultCustomField(
        id: 'f1',
        label: 'Customer ID',
        value: 'CUST-849201',
        isConcealed: false,
      );

      final map = field1.toMap();
      expect(map['id'], 'f1');
      expect(map['label'], 'Customer ID');
      expect(map['value'], 'CUST-849201');
      expect(map['isConcealed'], false);

      final reconstructed = VaultCustomField.fromMap(map);
      expect(reconstructed, field1);
      expect(reconstructed.hashCode, field1.hashCode);
    });

    test('VaultPasswordEntry preserves alphanumeric PINs (cUdXa) and custom fields', () {
      final entry = VaultPasswordEntry(
        id: 'entry-alpha-1',
        title: 'Barclays Bank UK',
        username: 'alex_uk',
        pin: 'cUdXa',
        transactionPin: '7bX9',
        customFields: const [
          VaultCustomField(
            id: 'cf-1',
            label: 'Memorable Word',
            value: 'SuperSecretWord',
            isConcealed: true,
          ),
          VaultCustomField(
            id: 'cf-2',
            label: 'Passcode Digit #3',
            value: '9',
            isConcealed: false,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(entry.pin, 'cUdXa');
      expect(entry.transactionPin, '7bX9');
      expect(entry.isPinAlphanumeric, true);
      expect(entry.isTransactionPinAlphanumeric, true);
      expect(entry.hasCustomFields, true);
      expect(entry.customFields.length, 2);

      // JSON Roundtrip test
      final jsonStr = entry.toJson();
      final restored = VaultPasswordEntry.fromJson(jsonStr);

      expect(restored.pin, 'cUdXa');
      expect(restored.transactionPin, '7bX9');
      expect(restored.isPinAlphanumeric, true);
      expect(restored.customFields.length, 2);
      expect(restored.customFields[0].label, 'Memorable Word');
      expect(restored.customFields[0].value, 'SuperSecretWord');
      expect(restored.customFields[0].isConcealed, true);
      expect(restored.customFields[1].label, 'Passcode Digit #3');
      expect(restored.customFields[1].value, '9');
      expect(restored.customFields[1].isConcealed, false);
    });

    test('isPinAlphanumeric correctly distinguishes numeric vs alphanumeric codes', () {
      final numericEntry = VaultPasswordEntry(
        id: 'num-1',
        title: 'Standard ATM',
        username: '',
        pin: '1234',
        transactionPin: '987654',
        createdAt: now,
        updatedAt: now,
      );

      expect(numericEntry.isPinAlphanumeric, false);
      expect(numericEntry.isTransactionPinAlphanumeric, false);

      final mixedEntry = VaultPasswordEntry(
        id: 'mixed-1',
        title: 'Mixed Alphanumeric PIN',
        username: '',
        pin: 'A92B',
        transactionPin: 'cUdXa',
        createdAt: now,
        updatedAt: now,
      );

      expect(mixedEntry.isPinAlphanumeric, true);
      expect(mixedEntry.isTransactionPinAlphanumeric, true);
    });
  });

  group('VxbBackupService Alphanumeric & Custom Fields Backup Tests', () {
    test('Exports and restores alphanumeric PINs and custom fields with 100% fidelity', () async {
      final service = VxbBackupService();
      final originalEntry = VaultPasswordEntry(
        id: 'backup-alpha-entry',
        title: 'Revolut UK',
        username: 'rev_user',
        password: 'PrimaryPassword123!',
        pin: 'cUdXa',
        transactionPin: 'Alpha77',
        customFields: const [
          VaultCustomField(
            id: 'cf-grid',
            label: 'Debit Grid B3',
            value: '74',
            isConcealed: true,
          ),
          VaultCustomField(
            id: 'cf-cif',
            label: 'Customer CIF',
            value: '99201488',
            isConcealed: false,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final backupStr = await service.exportBackup(
        passwords: [originalEntry],
        cards: [],
        backupPassword: 'MasterBackupPass99!',
      );

      final payload = await service.restoreBackup(
        fileContent: backupStr,
        backupPassword: 'MasterBackupPass99!',
      );

      expect(payload.passwords.length, 1);
      final restored = payload.passwords.first;
      expect(restored.title, 'Revolut UK');
      expect(restored.pin, 'cUdXa');
      expect(restored.transactionPin, 'Alpha77');
      expect(restored.customFields.length, 2);
      expect(restored.customFields[0].label, 'Debit Grid B3');
      expect(restored.customFields[0].value, '74');
      expect(restored.customFields[0].isConcealed, true);
      expect(restored.customFields[1].label, 'Customer CIF');
      expect(restored.customFields[1].value, '99201488');
      expect(restored.customFields[1].isConcealed, false);
    });
  });

  group('CharacterIndexerChips Widget Tests', () {
    testWidgets('Renders 1-based indexed chips for secret cUdXa', (tester) async {
      String? copiedChar;

      await tester.pumpWidget(
        _buildTestApp(
          CharacterIndexerChips(
            secret: 'cUdXa',
            isRevealed: true,
            label: 'Memorable Word Index',
            onCharacterCopied: (char) => copiedChar = char,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Memorable Word Index'), findsOneWidget);
      expect(find.text('Tap chip to copy'), findsOneWidget);

      // Verify all 5 indices (1, 2, 3, 4, 5) and characters (c, U, d, X, a) are displayed
      expect(find.text('1'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('U'), findsOneWidget);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('d'), findsOneWidget);

      expect(find.text('4'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);

      expect(find.text('5'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);

      // Tap character #2 ('U')
      await tester.tap(find.text('U'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(copiedChar, 'U');
    });

    testWidgets('Displays masked dots when isRevealed is false', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const CharacterIndexerChips(
            secret: 'cUdXa',
            isRevealed: false,
            label: 'Masked PIN',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Masked PIN'), findsOneWidget);
      // All 5 characters should be masked with ●
      expect(find.text('●'), findsNWidgets(5));
      expect(find.text('c'), findsNothing);
      expect(find.text('U'), findsNothing);
    });
  });

  group('Add & Edit Screen Custom Fields Integration Tests', () {
    testWidgets('AddPasswordScreen allows adding, editing, and saving custom fields', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = VaultPasswordsNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultPasswordsProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AddPasswordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter title
      await tester.enterText(find.byType(TextField).first, 'Chase Private Bank');
      await tester.pump();

      // Enter alphanumeric PIN (cUdXa)
      final pinField = find.widgetWithText(TextField, 'Bank / ATM PIN');
      expect(pinField, findsOneWidget);
      await tester.enterText(pinField, 'cUdXa');
      await tester.pump();

      // Scroll to and tap preset chip 'Customer ID'
      await tester.ensureVisible(find.text('Customer ID'));
      await tester.tap(find.text('Customer ID'));
      await tester.pumpAndSettle();

      // Fill in value for the custom field
      final valueField = find.widgetWithText(TextField, 'Secret value');
      expect(valueField, findsOneWidget);
      await tester.enterText(valueField, 'CHASE-00918');
      await tester.pump();

      // Tap Done/Save
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      // Verify the credential was saved with alphanumeric PIN and custom field
      final saved = notifier.state.allEntries.firstWhere((e) => e.title == 'Chase Private Bank');
      expect(saved.pin, 'cUdXa');
      expect(saved.customFields.length, 1);
      expect(saved.customFields.first.label, 'Customer ID');
      expect(saved.customFields.first.value, 'CHASE-00918');
    });

    testWidgets('EditPasswordScreen loads and permits reordering custom fields', (tester) async {
      final existing = VaultPasswordEntry(
        id: 'edit-test-1',
        title: 'HSBC Global',
        username: 'hsbc_user',
        pin: 'cUdXa',
        customFields: const [
          VaultCustomField(id: 'cf-a', label: 'Field A', value: 'ValA'),
          VaultCustomField(id: 'cf-b', label: 'Field B', value: 'ValB'),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final notifier = VaultPasswordsNotifier();
      notifier.addPassword(existing);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultPasswordsProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: EditPasswordScreen(entry: existing),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Field A'), findsOneWidget);
      expect(find.text('Field B'), findsOneWidget);
      expect(find.text('cUdXa'), findsOneWidget);

      // Tap move down arrow on Field A to swap order
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();

      // Tap Done/Save
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      final updated = notifier.state.allEntries.firstWhere((e) => e.id == 'edit-test-1');
      expect(updated.customFields.first.label, 'Field B');
      expect(updated.customFields.last.label, 'Field A');
    });
  });

  group('Desktop Detail Pane & Mobile Sheet Inspection Tests', () {
    testWidgets('DesktopCredentialDetailPane renders custom fields and CharacterIndexerChips when revealed', (tester) async {
      final entry = VaultPasswordEntry(
        id: 'desktop-cf-1',
        title: 'Scottish Bank',
        username: 'scottish_user',
        pin: 'cUdXa',
        customFields: const [
          VaultCustomField(
            id: 'cf-mem',
            label: 'Memorable Word',
            value: 'CastleHigh',
            isConcealed: true,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _buildTestApp(
          DesktopCredentialDetailPane(entry: entry),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CUSTOM SECURE FIELDS'), findsOneWidget);
      expect(find.text('Memorable Word'), findsOneWidget);

      // Unmask the PIN
      final showPinButtons = find.byTooltip('Reveal Bank / ATM PIN');
      expect(showPinButtons, findsOneWidget);
      await tester.tap(showPinButtons);
      await tester.pumpAndSettle();

      // PIN Character Position Index should appear with c, U, d, X, a
      expect(find.text('PIN Character Position Index'), findsOneWidget);
      expect(find.text('cUdXa'), findsOneWidget);
    });

    testWidgets('Mobile inspection sheet reveals alphanumeric PIN with CharacterIndexerChips', (tester) async {
      final entry = VaultPasswordEntry(
        id: 'mobile-cf-1',
        title: 'UK NatWest',
        username: 'natwest_user',
        password: '',
        pin: 'cUdXa',
        createdAt: now,
        updatedAt: now,
      );

      final notifier = VaultPasswordsNotifier();
      notifier.addPassword(entry);

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

      // Open inspection sheet
      await tester.tap(find.text('UK NatWest'));
      await tester.pumpAndSettle();

      // Reveal PIN
      await tester.tap(find.byTooltip('Show PIN'));
      await tester.pumpAndSettle();

      // Character indexer should be visible with cUdXa chips
      expect(find.text('ATM PIN Character Position Index'), findsOneWidget);
      expect(find.text('cUdXa'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(CharacterIndexerChips), matching: find.text('c')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(CharacterIndexerChips), matching: find.text('U')),
        findsOneWidget,
      );
    });
  });
}
