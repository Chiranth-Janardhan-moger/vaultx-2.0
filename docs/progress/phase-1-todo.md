# Phase 1 Todo List — Project Scaffold & CI Matrix

**Phase:** Phase 1 — Project Scaffold & CI Matrix  
**Owner:** Architect  
**Status:** Completed  

---

## Numbered Task Checklist

- [x] **1.1** Ensure Flutter SDK environment is available on host machine:
  - Cloned Flutter 3.47.2 stable SDK into `D:\flutter`.
  - Added `D:\flutter\bin` to user PATH and environment.
- [x] **1.2** Initialize Flutter application named `VaultX` with package ID `com.VaultX.vault` targeting Android, iOS, Windows, and macOS:
  - Executed: `flutter create --org com.VaultX --project-name VaultX --platforms=android,ios,windows,macos .`
  - Configured `applicationId = "com.VaultX.vault"` and `minSdk = 23` in `android/app/build.gradle.kts`.
  - Configured permissions (biometric, network, camera) and label `VaultX` in `android/app/src/main/AndroidManifest.xml`.
  - Configured `CFBundleDisplayName = "VaultX"` and privacy descriptions (Face ID, Camera, Bonjour, Local Network) in `ios/Runner/Info.plist`.
  - Configured `PRODUCT_NAME = "VaultX"` and `PRODUCT_BUNDLE_IDENTIFIER = "com.VaultX.vault"` in `macos/Runner/Configs/AppInfo.xcconfig`.
  - Configured `VaultX` window title and product details in `windows/runner/main.cpp` and `windows/runner/Runner.rc`.
- [x] **1.3** Establish feature-first folder architecture per §5/§8:
  - `lib/core/crypto/` (Argon2id KDF, AES-256-GCM, X25519 ECDH, HKDF)
  - `lib/core/storage/` (Drift SQLite database, Secure Storage service)
  - `lib/core/theme/` (Dual ColorScheme, Typography, Shape tokens, ThemeMode provider)
  - `lib/features/auth/` (Login / Sign Up, master key unlock, biometric gate)
  - `lib/features/vault/` (Passwords vault list, detail sheet, add/edit, generator)
  - `lib/features/wallet/` (Digital wallet cards list, card shaders, add card)
  - [x] `lib/features/sync/` (LAN mDNS discovery, QR rendezvous, WebSocket session, verification code, relay client)
  - [x] `lib/features/settings/` (Theme switcher, security options, danger zone wipe)
- [x] **1.4** Configure dependencies and pin versions in `pubspec.yaml`:
  - State management: `flutter_riverpod: ^2.6.1`
  - Local storage: `drift: ^2.24.2`, `drift_flutter: ^0.2.4`, `sqlite3_flutter_libs: ^0.5.28`, `path_provider: ^2.1.5`, `path: ^1.9.0`
  - Hardware secrets: `flutter_secure_storage: ^9.2.2`
  - Cryptography: `cryptography: ^2.7.2`, `crypto: ^3.0.6`
  - Biometrics: `local_auth: ^2.3.0`
  - Networking & Discovery: `bonsoir: ^5.1.0`, `web_socket_channel: ^3.0.1`
  - QR code: `qr_flutter: ^4.1.0`, `mobile_scanner: ^6.0.4`
  - Dev/Testing: `drift_dev: ^2.24.2`, `build_runner: ^2.4.14`, `mocktail: ^1.0.4`, `flutter_lints: ^5.0.0`
  - Resolved and downloaded all 99 dependencies via `flutter pub get`.
- [x] **1.5** Configure code quality and lint rules:
  - Configured strict analysis options in `analysis_options.yaml` (strict-casts, strict-inference, strict-raw-types).
  - Implemented secret leak / plaintext logging detection scripts: `scripts/check_secrets_log.ps1` and `scripts/check_secrets_log.sh`.
- [x] **1.6** Construct multi-platform GitHub Actions CI Matrix (`.github/workflows/ci.yml`) per §0.1:
  - `ubuntu-latest`: Android APK build, static analysis (`flutter analyze`), unit & widget test runner, plaintext secret grep check.
  - `windows-latest`: Windows desktop executable build.
  - `macos-latest`: Matrix for iOS (`flutter build ios --no-codesign`) and macOS (`flutter build macos`).
- [x] **1.7** Verify local build, run static analysis and tests locally:
  - `flutter analyze` -> `No issues found!` (0 errors, 0 warnings, 0 infos).
  - `flutter test` -> `All tests passed!` (`test/widget_test.dart`).
  - `check_secrets_log.ps1` -> `Zero sensitive logging violations found in lib.`
