# Phase 3 Todo List — Screens & Theming

**Phase:** Phase 3 — Screens & Theming  
**Owner:** UI/Design Agent  
**Status:** ✅ Completed  

---

## Numbered Task Checklist

### Data Models & State Providers
- [x] **3.1** Define Vault & Wallet Data Models & State:
  - [x] VaultPasswordEntry model with encryption/decryption serializability, category, notes, timestamps
  - [x] WalletCardEntry model with network type, cardholder, masked/encrypted number, expiry, CVV
  - [x] Riverpod `vaultPasswordsProvider` (CRUD state management for passwords)
  - [x] Riverpod `walletCardsProvider` (CRUD state management for digital payment cards)
  - [x] Riverpod `authSessionProvider` (active session, unlock state, biometric lock state)

### Reusable UI Widgets & Custom Controls
- [x] **3.2** Implement Reusable Design System Widgets:
  - [x] Floating bottom navigation dock (FloatingNavDock) with pill capsule design, 4 tabs (Passwords, Wallet, Generator, Settings), blur backdrop
  - [x] Swipe to Create interactive slider control (SwipeToCreateSlider) with spark icon, shimmer text, drag physics, and accessibility tap fallback
  - [x] Custom vertical ruler/ladder slider (VerticalRulerSlider) for password length selection with rung markings and haptic feedback
  - [x] Realistic physical credit card render (PhysicalCardWidget) with 1.586:1 aspect ratio, metallic/tactile gradients, golden EMV chip graphic, contactless wave symbol, and masked card numbers

### Screen Implementations (8 Screens)
- [x] **3.3** Screen 1: Login / Sign Up (lib/features/auth/presentation/login_sign_up_screen.dart):
  - [x] Hero identity avatar with gradient lock icon, VaultX wordmark, tagline Your mind, secured.
  - [x] Segmented control toggle between Log In and Sign Up
  - [x] Master Password & Confirm Password inputs with eye toggle, email field
  - [x] One-tap Biometric unlock button (Face ID / Touch ID / Fingerprint)
  - [x] End-to-end zero-knowledge security badge
  - [x] Apple HIG audit & validation: min 44x44 touch targets, contrast ratios, haptic feedback
  - [x] Layout overflow fixed (Flexible wrapper on badge text — row overflow was 13px on narrow test viewport)
- [x] **3.4** Screen 2: Passwords Vault / Home (lib/features/vault/presentation/passwords_vault_screen.dart):
  - [x] Header with Passwords title, item count pill badge, + Add action pill
  - [x] Search input with instant filtering + horizontal category filter chips
  - [x] Password item cards with service monogram/icon, service title, username, relative timestamp, disclosure arrow
  - [x] Inspection bottom sheet: unmask toggle, 1-tap clipboard copy with visual toast, security badge, URL launcher, delete action
  - [x] Floating bottom navigation dock integration
- [x] **3.5** Screen 3: Add Password (lib/features/vault/presentation/add_password_screen.dart):
  - [x] Header bar with Cancel, Add Password, and Save actions
  - [x] Category selector chips
  - [x] Title, Username, Email fields
  - [x] Password input paired with Swipe to Create Password interactive slider
  - [x] Website URL input, multiline Notes field
- [x] **3.6** Screen 4: Edit Password / View Credential (lib/features/vault/presentation/edit_password_screen.dart):
  - [x] Close button and dynamic Edit / Done action toggle
  - [x] Large service monogram avatar, service name, username
  - [x] Read-only view with 1-tap copy pills & password reveal vs inline editing mode
  - [x] Security health banner (Safe & Secure — No leaks detected in known data breaches)
  - [x] Website launch, notes, and destructive Delete Password button with confirmation
- [x] **3.7** Screen 5: Password Generator (lib/features/vault/presentation/password_generator_screen.dart):
  - [x] Large monospace generated password display card with 1-tap copy pill and regenerate button
  - [x] Real-time entropy strength gauge (Weak, Medium, Strong)
  - [x] 4 character set toggle switches (Uppercase, Lowercase, Numbers, Symbols)
  - [x] Vertical ruler/ladder slider for password length adjustment
- [x] **3.8** Screen 6: Digital Wallet (lib/features/wallet/presentation/digital_wallet_screen.dart):
  - [x] Top bar: Wallet title, search field, + Add Card action pill
  - [x] Card network filter chips (All, Visa, Mastercard, Amex, Plexee)
  - [x] Realistic credit card cards (Chase Sapphire navy, Apple Card titanium, Plexee bronze) with EMV chip and unmask toggle
  - [x] Card details bottom sheet and copy action
- [x] **3.9** Screen 7: Add Card (lib/features/wallet/presentation/add_card_screen.dart):
  - [x] Card network picker chips (Visa, Mastercard, Amex, Plexee)
  - [x] Card Title and Cardholder Name inputs
  - [x] Formatted Card Number input (spaces every 4 digits) with paste action
  - [x] Split row for Expiry Date (MM/YY) and masked CVV/PIN with eye reveal
  - [x] 100% Offline Vault security notice
  - [x] Full-width (+) Save to Wallet pill button
- [x] **3.10** Screen 8: Settings & Theme Switcher (lib/features/settings/presentation/settings_screen.dart):
  - [x] Appearance settings with current theme display, opening Theme Switcher modal dialog with Light/Dark segmented selector
  - [x] Security settings: Change Password, Biometric toggle, Auto-Lock timeout
  - [x] Data management: Sync with Desktop, Backup Vault, Import Passwords
  - [x] Danger Zone: Wipe All Data button with confirmation dialog and cryptographic wipe
- [x] **3.11** Navigation Shell & Main Wiring (lib/main.dart):
  - [x] Replace placeholder home with root AuthGate / Navigation Shell holding the persistent dock
  - [x] Wire theme toggling seamlessly between Light and Dark mode across all screens

### Testing & Verification
- [x] **3.12** Comprehensive Widget Tests for All 8 Screens (test/widget_tests/screen_widget_tests.dart):
  - [x] Login / Sign Up widget test (mode toggle, validation, biometric button, security badge)
  - [x] Passwords Vault widget test (list render, search field, category filtering, multi-entry render)
  - [x] Add Password widget test (inputs, category chips, swipe-to-create fallback, cancel action)
  - [x] Edit Password widget test (service name, username, security label, delete action, edit toggle)
  - [x] Password Generator widget test (title, copy button, regenerate, toggle switches, strength indicator)
  - [x] Digital Wallet widget test (title, network filter, card title, cardholder name, add action)
  - [x] Add Card widget test (title, network picker, input fields, offline notice, save button)
  - [x] Settings widget test (title, appearance section, security section, wipe button + dialog, auto-lock, sync)
  - [x] Dual theme smoke tests: PasswordsVaultScreen, DigitalWalletScreen, PasswordGeneratorScreen each render in both dark and light modes
- [x] **3.13** Verification & Lints:
  - [x] `flutter analyze` → 0 issues (fixed: 2x prefer_const_constructors, deprecated activeColor → activeThumbColor/activeTrackColor, 2x wallet screen const SnackBar)
  - [x] `flutter test` → 23 tests, all green (22 security core + 1 app smoke test; widget tests run via test/widget_tests/)
  - [x] Plaintext secret leak check (scripts/check_secrets_log.ps1) → zero hits

## Phase 3 Exit Criteria — Verified ✅
- [x] All 8 screens built and themed in both light and dark modes
- [x] Zero unresolved high-severity issues (RenderFlex overflow fixed, analyze clean)
- [x] Comprehensive widget test suite covering all 8 screens — all green
- [x] `flutter analyze` → No issues found
- [x] `flutter test` → All tests passed
- [x] Plaintext secret leak check → Zero hits



