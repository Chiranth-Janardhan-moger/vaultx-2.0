import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/features/desktop/presentation/command_palette_dialog.dart';
import 'package:vaultx/features/desktop/presentation/desktop_master_detail_view.dart';
import 'package:vaultx/features/desktop/presentation/widgets/desktop_credential_detail_pane.dart';
import 'package:vaultx/features/desktop/presentation/widgets/desktop_title_bar.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';

Widget _buildTestApp(Widget child, {List<VaultPasswordEntry> entries = const []}) {
  return ProviderScope(
    overrides: [
      vaultPasswordsProvider.overrideWith(
        (_) => _MockVaultNotifier(VaultPasswordsState(allEntries: entries)),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

class _MockVaultNotifier extends VaultPasswordsNotifier {
  _MockVaultNotifier(VaultPasswordsState initial) {
    state = initial;
  }
}

void main() {
  final now = DateTime(2026, 10, 23, 14, 0);

  final sampleEntries = [
    VaultPasswordEntry(
      id: 'e1',
      title: 'GitHub Work Account',
      username: 'octocat',
      email: 'octo@github.com',
      password: 'SecretWorkPassword123!',
      totpSecret: 'JBSWY3DPEHPK3PXP', // Valid Base32 TOTP secret
      category: 'Work',
      websiteUrl: 'https://github.com',
      createdAt: now,
      updatedAt: now,
    ),
    VaultPasswordEntry(
      id: 'e2',
      title: 'HDFC Bank ATM',
      username: '',
      pin: '4829',
      transactionPin: '918273',
      category: 'Banking',
      createdAt: now,
      updatedAt: now,
    ),
    VaultPasswordEntry(
      id: 'e3',
      title: 'Confidential Seed Phrase',
      username: '',
      password: '',
      notes: 'apple banana cherry dragon elephant falcon giraffe hotel',
      category: 'Notes',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  group('DesktopTitleBar Tests', () {
    testWidgets('DesktopTitleBar renders brand, 100% Local Vault status, and Omnibar trigger', (tester) async {
      bool paletteOpened = false;

      await tester.pumpWidget(
        _buildTestApp(
          DesktopTitleBar(
            onOpenCommandPalette: () => paletteOpened = true,
          ),
          entries: sampleEntries,
        ),
      );

      expect(find.text('VaultX'), findsOneWidget);
      expect(find.text('100% Local Vault'), findsOneWidget);
      expect(find.text('Search vault or run command...'), findsOneWidget);
      expect(find.text('Ctrl K'), findsOneWidget);

      // Tapping the Omnibar trigger invokes onOpenCommandPalette
      await tester.tap(find.text('Search vault or run command...'));
      await tester.pump();
      expect(paletteOpened, isTrue);
    });
  });

  group('CommandPaletteDialog Tests', () {
    testWidgets('CommandPaletteDialog renders Omnibar, fuzzy searches credentials, and executes selection', (tester) async {
      VaultPasswordEntry? selectedEntry;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CommandPaletteDialog.show(
                  context,
                  onSelectEntry: (entry) => selectedEntry = entry,
                );
              },
              child: const Text('Open Omnibar'),
            ),
          ),
          entries: sampleEntries,
        ),
      );

      // Open palette dialog
      await tester.tap(find.text('Open Omnibar'));
      await tester.pumpAndSettle();

      expect(find.text('Type a credential, bank PIN, or command...'), findsOneWidget);
      expect(find.text('GitHub Work Account'), findsOneWidget);
      expect(find.text('HDFC Bank ATM'), findsOneWidget);
      expect(find.text('Confidential Seed Phrase'), findsOneWidget);

      // Search for "HDFC"
      await tester.enterText(find.byType(TextField), 'HDFC');
      await tester.pump();

      expect(find.text('HDFC Bank ATM'), findsOneWidget);
      expect(find.text('GitHub Work Account'), findsNothing);

      // Tap HDFC Bank ATM item
      await tester.tap(find.text('HDFC Bank ATM'));
      await tester.pumpAndSettle();

      expect(selectedEntry?.title, 'HDFC Bank ATM');
    });

    testWidgets('CommandPaletteDialog displays quick actions', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CommandPaletteDialog.show(context),
              child: const Text('Open'),
            ),
          ),
          entries: const [],
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Credential'), findsOneWidget);
      expect(find.text('Add Bank / ATM / UPI PIN'), findsOneWidget);
      expect(find.text('Add Payment Card'), findsOneWidget);
      expect(find.text('Run Security Watchtower Audit'), findsOneWidget);
      expect(find.text('Lock Vault Now'), findsOneWidget);
    });
  });

  group('DesktopCredentialDetailPane Tests', () {
    testWidgets('Detail pane renders empty state placeholder when entry is null', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const DesktopCredentialDetailPane(entry: null),
        ),
      );

      expect(find.text('Select a credential to inspect'), findsOneWidget);
      expect(find.textContaining('Use arrow keys'), findsOneWidget);
    });

    testWidgets('Detail pane renders standard login credential with live TOTP code and entropy', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          DesktopCredentialDetailPane(entry: sampleEntries[0]),
        ),
      );

      expect(find.text('GitHub Work Account'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('octocat'), findsOneWidget);
      expect(find.text('https://github.com'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.textContaining('entropy'), findsOneWidget);
      expect(find.text('Two-Factor Authenticator (TOTP)'), findsOneWidget);

      // Verify unmasking toggle
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pump();

      expect(find.text('SecretWorkPassword123!'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    });

    testWidgets('Detail pane renders bank PIN entry with masked dots and keypad button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          DesktopCredentialDetailPane(entry: sampleEntries[1]),
        ),
      );

      expect(find.text('HDFC Bank ATM'), findsOneWidget);
      expect(find.text('Bank / ATM PIN'), findsOneWidget);
      expect(find.text('UPI / Transaction PIN'), findsOneWidget);
      expect(find.byIcon(Icons.dialpad_rounded), findsWidgets);
    });

    testWidgets('Detail pane renders secure notes content', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          DesktopCredentialDetailPane(entry: sampleEntries[2]),
        ),
      );

      expect(find.text('Confidential Seed Phrase'), findsOneWidget);
      expect(find.text('Encrypted Notes'), findsOneWidget);
      expect(find.text('apple banana cherry dragon elephant falcon giraffe hotel'), findsOneWidget);
    });
  });

  group('DesktopMasterDetailView Tests', () {
    testWidgets('DesktopMasterDetailView renders TitleBar, GlidingCategoryBar, and Master List', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const DesktopMasterDetailView(),
          entries: sampleEntries,
        ),
      );

      expect(find.text('VaultX'), findsOneWidget);
      expect(find.text('100% Local Vault'), findsOneWidget);
      expect(find.text('Search vault or run command...'), findsOneWidget);

      // Verify master entries list & initial selection
      expect(find.text('GitHub Work Account'), findsWidgets);
      expect(find.text('HDFC Bank ATM'), findsOneWidget);
      expect(find.text('Confidential Seed Phrase'), findsOneWidget);

      // Selecting the second item (HDFC Bank ATM) displays it in the detail pane
      await tester.tap(find.text('HDFC Bank ATM').first);
      await tester.pump();

      expect(find.text('Bank / ATM PIN'), findsOneWidget);
      expect(find.text('UPI / Transaction PIN'), findsOneWidget);
    });
  });
}
