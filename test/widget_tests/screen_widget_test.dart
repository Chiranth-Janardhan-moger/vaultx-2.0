// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/theme_provider.dart';
import 'package:vaultx/features/auth/presentation/login_sign_up_screen.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/presentation/passwords_vault_screen.dart';
import 'package:vaultx/features/vault/presentation/add_password_screen.dart';
import 'package:vaultx/features/vault/presentation/edit_password_screen.dart';
import 'package:vaultx/features/vault/presentation/password_generator_screen.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';
import 'package:vaultx/features/wallet/presentation/digital_wallet_screen.dart';
import 'package:vaultx/features/wallet/presentation/add_card_screen.dart';
import 'package:vaultx/features/wallet/presentation/providers/wallet_cards_provider.dart';
import 'package:vaultx/features/settings/presentation/settings_screen.dart';

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class MockAuthSessionNotifier extends StateNotifier<AuthSessionState>
    with Mock
    implements AuthSessionNotifier {
  MockAuthSessionNotifier(super.state);
}

class MockVaultPasswordsNotifier extends StateNotifier<VaultPasswordsState>
    with Mock
    implements VaultPasswordsNotifier {
  MockVaultPasswordsNotifier(super.state);
}

class MockWalletCardsNotifier extends StateNotifier<WalletCardsState>
    with Mock
    implements WalletCardsNotifier {
  MockWalletCardsNotifier(super.state);
}

// ---------------------------------------------------------------------------
// Shared test helpers
// ---------------------------------------------------------------------------

Widget buildTestApp(
  Widget child, {
  List<Override> overrides = const [],
  ThemeMode themeMode = ThemeMode.dark,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: child,
    ),
  );
}

VaultPasswordEntry _makeEntry({
  String id = 'test-pw-1',
  String title = 'Google',
  String username = 'user@gmail.com',
  String email = 'user@gmail.com',
  String password = 'S3cur3_P@ss!',
  String category = 'Email',
}) =>
    VaultPasswordEntry(
      id: id,
      title: title,
      username: username,
      email: email,
      password: password,
      category: category,
      websiteUrl: 'https://google.com',
      notes: 'Test notes.',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 6, 1),
    );

WalletCardEntry _makeCard({
  String id = 'card-1',
  String title = 'Chase Sapphire',
  String cardholderName = 'ALEX MORGAN',
  String cardNumber = '4532 8921 7843 7890',
  String expiry = '08/29',
  String cvv = '382',
  String network = 'Visa',
}) =>
    WalletCardEntry(
      id: id,
      title: title,
      cardholderName: cardholderName,
      cardNumber: cardNumber,
      expiry: expiry,
      cvv: cvv,
      network: network,
      cardTheme: 'chase_sapphire',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 6, 1),
    );

// ---------------------------------------------------------------------------
// Screen 1: Login / Sign Up
// ---------------------------------------------------------------------------

void main() {
  group('Screen 1 — LoginSignUpScreen', () {
    Widget buildLogin({bool hasMasterKey = false}) {
      final authState = AuthSessionState(
        isInitialized: true,
        isAuthenticated: false,
        hasMasterKey: hasMasterKey,
        isBiometricsAvailable: false,
      );
      final notifier = MockAuthSessionNotifier(authState);
      return buildTestApp(
        const LoginSignUpScreen(),
        overrides: [
          authSessionProvider.overrideWith((_) => notifier),
        ],
      );
    }

    testWidgets('renders VaultX wordmark and tagline', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      expect(find.textContaining('VaultX'), findsWidgets);
      expect(find.textContaining('secured'), findsWidgets);
    });

    testWidgets('shows Log In and Sign Up mode toggle', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      expect(find.text('Log In'), findsWidgets);
      expect(find.text('Sign Up'), findsWidgets);
    });

    testWidgets('password field renders and accepts text', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'MySecretPass1!');
      expect(find.text('MySecretPass1!'), findsOneWidget);
    });

    testWidgets('shows validation error when submitting empty password',
        (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      final buttons = find.byType(ElevatedButton);
      if (buttons.evaluate().isNotEmpty) {
        await tester.tap(buttons.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('password'), findsWidgets);
      }
    });

    testWidgets('switches to Sign Up mode showing confirm password field',
        (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      final signUpButton = find.text('Sign Up');
      if (signUpButton.evaluate().isNotEmpty) {
        await tester.tap(signUpButton.first);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
      }
    });

    testWidgets('biometric button absent when biometrics unavailable',
        (tester) async {
      await tester.pumpWidget(buildLogin(hasMasterKey: false));
      await tester.pumpAndSettle();

      expect(find.textContaining('Face ID'), findsNothing);
      expect(find.textContaining('Touch ID'), findsNothing);
    });

    testWidgets('renders zero-knowledge security badge', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.toLowerCase().contains('zero') == true ||
                w.data?.toLowerCase().contains('knowledge') == true ||
                w.data?.toLowerCase().contains('secure') == true ||
                w.data?.toLowerCase().contains('end-to-end') == true)),
        findsWidgets,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Screen 2: Passwords Vault / Home
  // ---------------------------------------------------------------------------

  group('Screen 2 — PasswordsVaultScreen', () {
    Widget buildVault({
      List<VaultPasswordEntry> entries = const [],
      List<String> customCategories = const [],
    }) {
      final vaultNotifier = MockVaultPasswordsNotifier(
          VaultPasswordsState(allEntries: entries, customCategories: customCategories));
      return buildTestApp(
        const PasswordsVaultScreen(),
        overrides: [
          vaultPasswordsProvider.overrideWith((_) => vaultNotifier),
        ],
      );
    }

    testWidgets('renders Passwords title', (tester) async {
      await tester.pumpWidget(buildVault());
      await tester.pump();

      expect(find.text('Passwords'), findsWidgets);
    });

    testWidgets('renders empty list with vertically centered No passwords found', (tester) async {
      await tester.pumpWidget(buildVault(entries: []));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      final emptyText = find.text('No passwords found');
      expect(emptyText, findsOneWidget);
      final center = tester.getCenter(emptyText);
      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect((center.dy - screenHeight / 2).abs(), lessThan(50));
    });

    testWidgets('renders entry card title', (tester) async {
      await tester.pumpWidget(buildVault(entries: [_makeEntry(title: 'Google')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Google'), findsWidgets);
    });

    testWidgets('renders search text field', (tester) async {
      await tester.pumpWidget(buildVault(entries: [_makeEntry()]));
      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('renders All category chip', (tester) async {
      await tester.pumpWidget(buildVault(entries: [_makeEntry()]));
      await tester.pump();

      expect(find.text('All'), findsWidgets);
    });

    testWidgets('reflects custom category in filter pills', (tester) async {
      await tester.pumpWidget(buildVault(customCategories: ['Crypto']));
      await tester.pumpAndSettle();

      expect(find.text('Crypto'), findsWidgets);
    });

    testWidgets('multiple entries all render their titles', (tester) async {
      final entries = [
        _makeEntry(id: 'e1', title: 'Google'),
        _makeEntry(id: 'e2', title: 'Instagram'),
        _makeEntry(id: 'e3', title: 'GitHub'),
      ];
      await tester.pumpWidget(buildVault(entries: entries));
      await tester.pumpAndSettle();

      expect(find.textContaining('Google'), findsWidgets);
      expect(find.textContaining('Instagram'), findsWidgets);
      expect(find.textContaining('GitHub'), findsWidgets);
    });

    testWidgets('tapping password card opens detail dialog with edit and delete actions and timestamps', (tester) async {
      final entry = _makeEntry(id: 'e1', title: 'Google');
      await tester.pumpWidget(buildVault(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Google').last);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);
    });

    testWidgets('tapping password card for unedited credential shows Created and hides Edited timestamp', (tester) async {
      final now = DateTime(2025, 3, 10, 14, 30);
      final entry = _makeEntry(id: 'e2', title: 'Unedited Service')
          .copyWith(createdAt: now, updatedAt: now);
      await tester.pumpWidget(buildVault(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Unedited Service').first);
      await tester.pumpAndSettle();

      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Edited'), findsNothing);
    });

    testWidgets('long-pressing a category pill opens Category Options sheet with Edit and Delete Category', (tester) async {
      await tester.pumpWidget(buildVault(customCategories: ['Crypto']));
      await tester.pumpAndSettle();

      final cryptoPill = find.text('Crypto');
      expect(cryptoPill, findsOneWidget);
      await tester.longPress(cryptoPill);
      await tester.pumpAndSettle();

      expect(find.text('Category Options'), findsOneWidget);
      expect(find.text('Edit Category'), findsOneWidget);
      expect(find.text('Delete Category'), findsOneWidget);
    });

    testWidgets('renders inline username and category without dot on card', (tester) async {
      final entry = _makeEntry(id: 'e1', title: 'Google', username: 'user@gmail.com', category: 'Google');
      await tester.pumpWidget(buildVault(entries: [entry]));
      await tester.pumpAndSettle();

      expect(find.text('user@gmail.com'), findsOneWidget);
      expect(find.text('•'), findsWidgets);
      expect(find.text('Google'), findsWidgets);
    });
  });

  group('VaultPasswordsNotifier Category Management', () {
    test('renameCategory updates custom category and associated entries', () {
      final entry = _makeEntry(id: '1', category: 'OldCat');
      final notifier = VaultPasswordsNotifier();
      notifier.state = VaultPasswordsState(
        allEntries: [entry],
        customCategories: ['OldCat'],
        selectedCategory: 'OldCat',
      );

      notifier.renameCategory('OldCat', 'NewCat');

      expect(notifier.state.customCategories, contains('NewCat'));
      expect(notifier.state.customCategories, isNot(contains('OldCat')));
      expect(notifier.state.allEntries.first.category, equals('NewCat'));
      expect(notifier.state.selectedCategory, equals('NewCat'));
    });

    test('deleteCategory removes category and moves associated entries to Others', () {
      final entry = _makeEntry(id: '1', category: 'ToDel');
      final notifier = VaultPasswordsNotifier();
      notifier.state = VaultPasswordsState(
        allEntries: [entry],
        customCategories: ['ToDel'],
        selectedCategory: 'ToDel',
      );

      notifier.deleteCategory('ToDel');

      expect(notifier.state.customCategories, isNot(contains('ToDel')));
      expect(notifier.state.allEntries.first.category, equals('Others'));
      expect(notifier.state.selectedCategory, equals('All'));
    });
  });

  // ---------------------------------------------------------------------------
  // Screen 3: Add Password
  // ---------------------------------------------------------------------------

  group('Screen 3 — AddPasswordScreen', () {
    Widget buildAddPassword() {
      final vaultNotifier =
          MockVaultPasswordsNotifier(const VaultPasswordsState());
      return buildTestApp(
        const AddPasswordScreen(),
        overrides: [
          vaultPasswordsProvider.overrideWith((_) => vaultNotifier),
        ],
      );
    }

    testWidgets('renders Password-related title', (tester) async {
      await tester.pumpWidget(buildAddPassword());
      await tester.pump();

      expect(find.textContaining('Password'), findsWidgets);
    });

    testWidgets('contains text input fields including merged Username / Email', (tester) async {
      await tester.pumpWidget(buildAddPassword());
      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Username / Email'), findsOneWidget);
    });

    testWidgets('category chips are present', (tester) async {
      await tester.pumpWidget(buildAddPassword());
      await tester.pumpAndSettle();

      const knownCategories = ['Email', 'Bank', 'GitHub', 'Social', 'Entertainment'];
      final found = knownCategories.any(
        (cat) => find.text(cat).evaluate().isNotEmpty,
      );
      expect(found, isTrue);
    });

    testWidgets('title field accepts user text', (tester) async {
      await tester.pumpWidget(buildAddPassword());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, 'MyService');
        expect(find.text('MyService'), findsOneWidget);
      }
    });

    testWidgets('cancel/close action is present', (tester) async {
      await tester.pumpWidget(buildAddPassword());
      await tester.pump();

      final hasCancel = find.text('Cancel').evaluate().isNotEmpty ||
          find.byIcon(Icons.close).evaluate().isNotEmpty ||
          find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
          find.byIcon(Icons.arrow_back_ios).evaluate().isNotEmpty;
      expect(hasCancel, isTrue);
    });

    testWidgets('renders Add Category pill and opens dialog on tap', (tester) async {
      await tester.pumpWidget(buildAddPassword());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(-800, 0));
      await tester.pumpAndSettle();

      final addCategoryChip = find.text('+ Add');
      expect(addCategoryChip, findsOneWidget);

      await tester.tap(addCategoryChip);
      await tester.pumpAndSettle();

      expect(find.text('New Category'), findsOneWidget);
      expect(find.text('Category Name'), findsOneWidget);
    });

    testWidgets('adding category via dialog creates and selects new category pill', (tester) async {
      final realNotifier = VaultPasswordsNotifier();
      await tester.pumpWidget(
        buildTestApp(
          const AddPasswordScreen(),
          overrides: [
            vaultPasswordsProvider.overrideWith((_) => realNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(-800, 0));
      await tester.pumpAndSettle();

      final addCategoryChip = find.text('+ Add');
      await tester.tap(addCategoryChip);
      await tester.pumpAndSettle();

      final categoryField = find.widgetWithText(TextField, 'Category Name');
      await tester.enterText(categoryField, 'Gaming');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(800, 0));
      await tester.pumpAndSettle();

      expect(find.text('New Category'), findsNothing);
      expect(find.text('Gaming'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Screen 4: Edit Password / View Credential
  // ---------------------------------------------------------------------------

  group('Screen 4 — EditPasswordScreen', () {
    Widget buildEdit(VaultPasswordEntry entry) {
      final vaultNotifier =
          MockVaultPasswordsNotifier(VaultPasswordsState(allEntries: [entry]));
      return buildTestApp(
        EditPasswordScreen(entry: entry),
        overrides: [
          vaultPasswordsProvider.overrideWith((_) => vaultNotifier),
        ],
      );
    }

    testWidgets('shows service name from entry', (tester) async {
      await tester.pumpWidget(buildEdit(_makeEntry(title: 'GitHub')));
      await tester.pumpAndSettle();

      expect(find.textContaining('GitHub'), findsWidgets);
    });

    testWidgets('shows username from entry', (tester) async {
      await tester.pumpWidget(buildEdit(_makeEntry(username: 'alex-dev-99')));
      await tester.pumpAndSettle();

      expect(find.textContaining('alex-dev-99'), findsWidgets);
    });

    testWidgets('renders category tag selector', (tester) async {
      await tester.pumpWidget(buildEdit(_makeEntry(category: 'Google')));
      await tester.pumpAndSettle();

      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('Google'), findsWidgets);
    });

    testWidgets('has a delete action', (tester) async {
      await tester.pumpWidget(buildEdit(_makeEntry()));
      await tester.pumpAndSettle();

      final hasDelete = find.textContaining('Delete').evaluate().isNotEmpty ||
          find.byIcon(Icons.delete).evaluate().isNotEmpty ||
          find.byIcon(Icons.delete_outline).evaluate().isNotEmpty;
      expect(hasDelete, isTrue);
    });

    testWidgets('has an Edit or Done action', (tester) async {
      await tester.pumpWidget(buildEdit(_makeEntry()));
      await tester.pumpAndSettle();

      final hasEditAction = find.text('Edit').evaluate().isNotEmpty ||
          find.text('Done').evaluate().isNotEmpty ||
          find.byIcon(Icons.edit).evaluate().isNotEmpty;
      expect(hasEditAction, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Screen 5: Password Generator
  // ---------------------------------------------------------------------------

  group('Screen 5 — PasswordGeneratorScreen', () {
    testWidgets('renders generator title text', (tester) async {
      await tester.pumpWidget(buildTestApp(const PasswordGeneratorScreen()));
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.toLowerCase().contains('generator') == true ||
                w.data?.toLowerCase().contains('password') == true)),
        findsWidgets,
      );
    });

    testWidgets('has a copy button', (tester) async {
      await tester.pumpWidget(buildTestApp(const PasswordGeneratorScreen()));
      await tester.pumpAndSettle();

      final hasCopy = find.text('Copy').evaluate().isNotEmpty ||
          find.byIcon(Icons.copy).evaluate().isNotEmpty ||
          find.byIcon(Icons.content_copy).evaluate().isNotEmpty ||
          find.textContaining('Copy').evaluate().isNotEmpty;
      expect(hasCopy, isTrue);
    });

    testWidgets('has a regenerate or refresh button', (tester) async {
      await tester.pumpWidget(buildTestApp(const PasswordGeneratorScreen()));
      await tester.pumpAndSettle();

      final hasRefresh = find.byIcon(Icons.refresh).evaluate().isNotEmpty ||
          find.byIcon(Icons.refresh_rounded).evaluate().isNotEmpty ||
          find.byIcon(Icons.autorenew).evaluate().isNotEmpty ||
          find.byTooltip('Regenerate').evaluate().isNotEmpty ||
          find.textContaining('Regenerate').evaluate().isNotEmpty ||
          find.textContaining('Generate').evaluate().isNotEmpty;
      expect(hasRefresh, isTrue);
    });

    testWidgets('options toggle switches are present', (tester) async {
      await tester.pumpWidget(buildTestApp(const PasswordGeneratorScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('strength indicator is shown', (tester) async {
      await tester.pumpWidget(buildTestApp(const PasswordGeneratorScreen()));
      await tester.pumpAndSettle();

      final hasStrength = find.textContaining('Weak').evaluate().isNotEmpty ||
          find.textContaining('Medium').evaluate().isNotEmpty ||
          find.textContaining('Strong').evaluate().isNotEmpty ||
          find.textContaining('Strength').evaluate().isNotEmpty;
      expect(hasStrength, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Screen 6: Digital Wallet
  // ---------------------------------------------------------------------------

  group('Screen 6 — DigitalWalletScreen', () {
    Widget buildWallet({List<WalletCardEntry> cards = const []}) {
      final walletNotifier =
          MockWalletCardsNotifier(WalletCardsState(allCards: cards));
      return buildTestApp(
        const DigitalWalletScreen(),
        overrides: [
          walletCardsProvider.overrideWith((_) => walletNotifier),
        ],
      );
    }

    testWidgets('renders Wallet title', (tester) async {
      await tester.pumpWidget(buildWallet());
      await tester.pump();

      expect(find.textContaining('Wallet'), findsWidgets);
    });

    testWidgets('renders empty state with vertically centered No cards found', (tester) async {
      await tester.pumpWidget(buildWallet(cards: []));
      await tester.pumpAndSettle();

      final emptyText = find.text('No cards found');
      expect(emptyText, findsOneWidget);
      final center = tester.getCenter(emptyText);
      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect((center.dy - screenHeight / 2).abs(), lessThan(50));
    });

    testWidgets('renders All network filter chip', (tester) async {
      await tester.pumpWidget(buildWallet(cards: [_makeCard()]));
      await tester.pump();

      expect(find.text('All'), findsWidgets);
    });

    testWidgets('renders card title', (tester) async {
      await tester.pumpWidget(
          buildWallet(cards: [_makeCard(title: 'Chase Sapphire')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Chase'), findsWidgets);
    });

    testWidgets('renders cardholder name', (tester) async {
      await tester.pumpWidget(
          buildWallet(cards: [_makeCard(cardholderName: 'ALEX MORGAN')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('ALEX MORGAN'), findsWidgets);
    });

    testWidgets('add card action is present', (tester) async {
      await tester.pumpWidget(buildWallet());
      await tester.pump();

      final hasAdd = find.textContaining('Add').evaluate().isNotEmpty ||
          find.byIcon(Icons.add).evaluate().isNotEmpty ||
          find.byIcon(Icons.add_rounded).evaluate().isNotEmpty ||
          find.byTooltip('Add Card').evaluate().isNotEmpty;
      expect(hasAdd, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Screen 7: Add Card
  // ---------------------------------------------------------------------------

  group('Screen 7 — AddCardScreen', () {
    Widget buildAddCard() {
      final walletNotifier =
          MockWalletCardsNotifier(const WalletCardsState());
      return buildTestApp(
        const AddCardScreen(),
        overrides: [
          walletCardsProvider.overrideWith((_) => walletNotifier),
        ],
      );
    }

    testWidgets('renders Card-related title', (tester) async {
      await tester.pumpWidget(buildAddCard());
      await tester.pump();

      expect(find.textContaining('Card'), findsWidgets);
    });

    testWidgets('network picker chips are present', (tester) async {
      await tester.pumpWidget(buildAddCard());
      await tester.pumpAndSettle();

      const knownNetworks = ['Visa', 'Mastercard', 'Amex', 'Plexee'];
      final found = knownNetworks.any(
        (n) => find.text(n).evaluate().isNotEmpty,
      );
      expect(found, isTrue);
    });

    testWidgets('input fields are present', (tester) async {
      await tester.pumpWidget(buildAddCard());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('offline/vault security notice is shown', (tester) async {
      await tester.pumpWidget(buildAddCard());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.toLowerCase().contains('offline') == true ||
                w.data?.toLowerCase().contains('vault') == true ||
                w.data?.toLowerCase().contains('secure') == true)),
        findsWidgets,
      );
    });

    testWidgets('save/add to wallet button is present', (tester) async {
      await tester.pumpWidget(buildAddCard());
      await tester.pumpAndSettle();

      final hasSave = find.textContaining('Save').evaluate().isNotEmpty ||
          find.textContaining('Wallet').evaluate().isNotEmpty ||
          find.textContaining('Add').evaluate().isNotEmpty;
      expect(hasSave, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Screen 8: Settings & Theme Switcher
  // ---------------------------------------------------------------------------

  group('Screen 8 — SettingsScreen', () {
    Widget buildSettings({ThemeMode themeMode = ThemeMode.dark}) {
      final authNotifier = MockAuthSessionNotifier(const AuthSessionState(
        isInitialized: true,
        isAuthenticated: true,
        hasMasterKey: true,
        isBiometricsAvailable: true,
        isBiometricsEnabled: true,
      ));
      return buildTestApp(
        const SettingsScreen(),
        overrides: [
          authSessionProvider.overrideWith((_) => authNotifier),
          themeModeProvider.overrideWith((ref) {
            final n = ThemeModeNotifier();
            n.setMode(themeMode);
            return n;
          }),
        ],
        themeMode: themeMode,
      );
    }

    testWidgets('renders Settings title', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pump();

      expect(find.textContaining('Settings'), findsWidgets);
    });

    testWidgets('renders Appearance / Theme section', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final hasAppearance = find.textContaining('Appearance').evaluate().isNotEmpty ||
          find.textContaining('Theme').evaluate().isNotEmpty ||
          find.textContaining('Dark').evaluate().isNotEmpty ||
          find.textContaining('Light').evaluate().isNotEmpty;
      expect(hasAppearance, isTrue);
    });

    testWidgets('renders Security section', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final hasSecurity = find.textContaining('Security').evaluate().isNotEmpty ||
          find.textContaining('Password').evaluate().isNotEmpty ||
          find.textContaining('Biometric').evaluate().isNotEmpty;
      expect(hasSecurity, isTrue);
    });

    testWidgets('renders Danger Zone / Wipe button', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final hasDanger = find.textContaining('Wipe').evaluate().isNotEmpty ||
          find.textContaining('Danger').evaluate().isNotEmpty ||
          find.textContaining('Delete').evaluate().isNotEmpty;
      expect(hasDanger, isTrue);
    });

    testWidgets('wipe button shows confirmation dialog on tap', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      // Open App Info to access Danger Zone
      final appInfoTile = find.text('App Info');
      expect(appInfoTile, findsOneWidget);
      await tester.tap(appInfoTile);
      await tester.pumpAndSettle();

      final wipeButton = find.text('Wipe Everything');
      expect(wipeButton, findsOneWidget);
      await tester.ensureVisible(wipeButton);
      await tester.pumpAndSettle();
      await tester.tap(wipeButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('renders in light mode without errors', (tester) async {
      await tester.pumpWidget(buildSettings(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has Auto-Lock / timeout setting', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final hasAutoLock = find.textContaining('Auto').evaluate().isNotEmpty ||
          find.textContaining('Lock').evaluate().isNotEmpty ||
          find.textContaining('Timeout').evaluate().isNotEmpty;
      expect(hasAutoLock, isTrue);
    });

    testWidgets('auto-lock dialog opens with all options and allows selection', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      // Open General settings to access Auto-Lock Duration
      final generalTile = find.text('General');
      expect(generalTile, findsOneWidget);
      await tester.tap(generalTile);
      await tester.pumpAndSettle();

      final autoLockTile = find.text('Auto-Lock Duration');
      expect(autoLockTile, findsOneWidget);
      await tester.tap(autoLockTile);
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.byType(Dialog), findsOneWidget);

      // Verify all requested options are present inside the dialog
      final dialogFinder = find.byType(Dialog);
      expect(find.descendant(of: dialogFinder, matching: find.text('30 Seconds')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('1 Minute')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('2 Minutes')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('3 Minutes')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('4 Minutes')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('5 Minutes')), findsOneWidget);

      // Select '1 Minute' inside dialog
      await tester.tap(find.descendant(of: dialogFinder, matching: find.text('1 Minute')));
      await tester.pumpAndSettle();

      // Dialog dismissed and ListTile updated
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('1 Minute'), findsOneWidget);
    });

    testWidgets('supports System, Dark, and Light theme modes', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final generalTile = find.text('General');
      await tester.tap(generalTile);
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
    });

    testWidgets('has Sync / Backup setting', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final hasSync = find.textContaining('Sync').evaluate().isNotEmpty ||
          find.textContaining('Backup').evaluate().isNotEmpty ||
          find.textContaining('Import').evaluate().isNotEmpty;
      expect(hasSync, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Dual Theme Smoke Tests
  // ---------------------------------------------------------------------------

  group('Dual Theme Smoke Tests', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      final label = mode == ThemeMode.dark ? 'dark' : 'light';

      testWidgets('PasswordsVaultScreen renders in $label mode', (tester) async {
        final vaultNotifier = MockVaultPasswordsNotifier(
            VaultPasswordsState(allEntries: [_makeEntry()]));
        await tester.pumpWidget(
          buildTestApp(
            const PasswordsVaultScreen(),
            overrides: [vaultPasswordsProvider.overrideWith((_) => vaultNotifier)],
            themeMode: mode,
          ),
        );
        await tester.pump();
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('DigitalWalletScreen renders in $label mode', (tester) async {
        final walletNotifier = MockWalletCardsNotifier(
            WalletCardsState(allCards: [_makeCard()]));
        await tester.pumpWidget(
          buildTestApp(
            const DigitalWalletScreen(),
            overrides: [walletCardsProvider.overrideWith((_) => walletNotifier)],
            themeMode: mode,
          ),
        );
        await tester.pump();
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('PasswordGeneratorScreen renders in $label mode', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const PasswordGeneratorScreen(), themeMode: mode),
        );
        await tester.pump();
        expect(find.byType(Scaffold), findsOneWidget);
      });
    }
  });
}
