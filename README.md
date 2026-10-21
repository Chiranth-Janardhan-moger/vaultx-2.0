# VaultX

> **Your mind, secured.** — A local-first, offline-capable password and card vault.

[![CI Matrix](https://github.com/navya24shree/VaultX/actions/workflows/ci.yml/badge.svg)](https://github.com/navya24shree/VaultX/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-stable-blue?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What is VaultX?

VaultX is an open-source, cross-platform **password manager and digital wallet** built with Flutter. It targets Android, iOS, Windows, and macOS from a single codebase.

**Core guarantees:**

- ?? Vault data is **AES-256-GCM encrypted at rest** — every entry individually, with a unique nonce per write.
- ?? The master key is derived via **Argon2id** from your master password — GPU-resistant, never stored in plaintext.
- ?? Master key lives **only in the platform secure enclave** (iOS/macOS Keychain, Android Keystore, Windows DPAPI).
- ?? **Biometric unlock** (Face ID / Touch ID / fingerprint) gates key retrieval.
- ?? **No cloud. No server. Zero knowledge.** Your data never leaves your devices in plaintext — including during sync.
- ?? **Device-to-device sync** over local Wi-Fi (mDNS) with WSS/443 relay fallback — all traffic encrypted end-to-end via X25519 ECDH + AES-256-GCM.

---

## Screenshots

> *8 screens: Login, Passwords Vault, Add Password, Edit Password, Password Generator, Digital Wallet, Add Card, Settings.*

---

## Architecture

### Feature-first folder structure

```
lib/
+-- core/
¦   +-- crypto/               # Argon2id KDF, AES-256-GCM, X25519 ECDH, HKDF
¦   ¦   +-- kdf_service.dart
¦   ¦   +-- vault_cipher.dart
¦   ¦   +-- biometric_auth_service.dart
¦   ¦   +-- lockout_policy.dart
¦   +-- storage/              # Drift SQLite index, secure key storage
¦   +-- theme/                # Dual ColorScheme (dark + light), typography, shape tokens
¦   +-- widgets/              # Shared reusable widgets (FloatingNavDock, SwipeToCreateSlider)
+-- features/
¦   +-- auth/                 # Login / Sign Up, master key unlock, biometric gate
¦   +-- vault/                # Passwords vault list, add/edit, password generator
¦   +-- wallet/               # Digital wallet card list, add card
¦   +-- sync/                 # LAN mDNS discovery, QR rendezvous, WebSocket, relay client
¦   +-- settings/             # Theme switcher, security options, danger zone wipe
+-- main.dart
```

### State management

**Riverpod** throughout — no `BuildContext`-coupled singletons, fully testable providers.

---

## Security Architecture

### At rest (§6.1)

| Layer | Implementation |
|---|---|
| Key derivation | Argon2id (64MB memory, 3 iterations, parallelism 1) from master password + per-install 16-byte CSPRNG salt |
| Key storage | `flutter_secure_storage` ? iOS/macOS Keychain, Android Keystore, Windows DPAPI |
| Biometric gate | `local_auth` gates retrieval; fallback to master password |
| Vault encryption | AES-256-GCM, each entry encrypted individually with a unique 96-bit nonce |
| Lockout policy | Exponential backoff after 3 failed unlocks; full cryptographic wipe at 10 attempts |

### Device-to-device sync (§6.2)

1. **Discovery:** mDNS (`_vaultx-sync._tcp`) on LAN; WSS/443 relay fallback cross-network.
2. **Rendezvous:** QR code encodes local IP, port, and short-lived session ID (pure rendezvous — no crypto weight).
3. **Key exchange:** Ephemeral X25519 keypair per session; ECDH shared secret.
4. **Verification code:** 6-digit code derived from `SHA-256(pubKeyA ? pubKeyB ? sharedSecret) mod 1,000,000` — **never an independently transmitted PIN** (Signal/Bluetooth Numeric Comparison model).
5. **Session encryption:** HKDF from shared secret ? AES-256-GCM per message.
6. **Session hygiene:** 60-second expiry, single-use verification code; master key never appears in QR or sync messages.
7. **Merge logic:** Last-write-wins per field via timestamps; missing entries added without clobbering newer local edits; conflicts surfaced to the user.

### Master password recovery

No cloud-assisted recovery exists by design. During onboarding, a cryptographically generated **Recovery Key** (256-bit / BIP-39 word list) is presented. The user must save this offline. If both master password and recovery key are lost, vault data is permanently unrecoverable — this is a feature, not a limitation.

---

## Tech Stack

| Concern | Package |
|---|---|
| Framework | Flutter (stable channel) |
| State | `flutter_riverpod ^2.6.1` |
| Local DB | `drift ^2.24.2` (SQLite) |
| Secure storage | `flutter_secure_storage ^9.2.2` |
| Crypto | `cryptography ^2.7.2`, `crypto ^3.0.6` |
| Biometrics | `local_auth ^2.3.0` |
| LAN discovery | `bonsoir ^5.1.0` (mDNS) |
| Transport | `web_socket_channel ^3.0.1` |
| QR | `qr_flutter ^4.1.0`, `mobile_scanner ^6.0.4` |
| Testing | `flutter_test`, `mocktail ^1.0.4` |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) — stable channel
- For Android: Android Studio + SDK (API 23+)
- For iOS/macOS: Xcode 15+ on macOS (Apple Silicon or Intel)
- For Windows: Visual Studio 2022 with "Desktop development with C++" workload

### Setup

```bash
# Clone the repository
git clone https://github.com/navya24shree/VaultX.git
cd VaultX

# Install Flutter dependencies
flutter pub get

# Run on your device/emulator
flutter run
```

### Platform-specific

```bash
# Android
flutter build apk --debug
flutter build appbundle --release  # requires signing config

# Windows
flutter build windows --release    # requires Developer Mode enabled

# iOS (macOS required)
flutter build ios --no-codesign --debug        # simulator / no-codesign
flutter build ios --release                    # requires provisioning profile

# macOS (macOS required)
flutter build macos --debug
```

---

## CI Matrix

All four target platforms are verified via GitHub Actions:

| Job | Runner | What it does |
|---|---|---|
| Lint + Tests + Security Scan | `ubuntu-latest` | `flutter analyze`, `flutter test --coverage`, secret-log grep |
| Android APK + AAB | `ubuntu-latest` | `flutter build apk --debug`, `flutter build appbundle --debug` |
| Windows Desktop | `windows-latest` | `flutter build windows --debug` |
| iOS (no-codesign) | `macos-latest` | `flutter build ios --no-codesign --debug` |
| macOS (unsigned) | `macos-latest` | `flutter build macos --debug` |

> **Note on iOS/macOS signing:** CI builds are unsigned/no-codesign builds used as build-compilation evidence (per §0.1 of the build brief). Production-signed artifacts require Apple Developer Program credentials with provisioning profiles and certificates configured as CI secrets — this step is documented here but not automated since credentials are not available in this environment.

---

## Running Tests

```bash
# All tests
flutter test

# Security core (Argon2id, AES-256-GCM, lockout)
flutter test test/security_core_test.dart

# Screen widget tests (all 8 screens, dual themes)
flutter test test/widget_tests/screen_widget_tests.dart

# Sync pairing (ECDH, 6-digit code, ciphertext-only wire)
flutter test test/sync_pairing_test.dart

# QA negative tests (expired session, reused code, malformed QR)
flutter test test/qa_negative_tests.dart

# Plaintext secret leak scan
./scripts/check_secrets_log.ps1   # Windows PowerShell
./scripts/check_secrets_log.sh lib # Linux/macOS
```

---

## Design System

- **Dark theme baseline:** `#020617` background, `#0080ff` primary, `#191c1e` surfaces, Hanken Grotesk / Inter / JetBrains Mono type scale, `#10b981` / `#f59e0b` / `#ef4444` status colors.
- **Light theme:** `#f8fafc` background, `#ffffff` cards, `#0080ff` primary (brand consistency).
- **Both themes** are built from day one as paired `ColorScheme`s from shared semantic tokens — not dark-first with light bolted on later.
- Every screen passed an **Apple HIG audit** (touch targets =44pt, contrast ratios, accessibility semantics).

---

## Project Documentation

| Document | Description |
|---|---|
| [`docs/design-audit.md`](docs/design-audit.md) | Per-screen audit against original design export |
| [`docs/design-decisions.md`](docs/design-decisions.md) | Every conflict resolved, every assumption logged |
| [`docs/progress/phase-N-todo.md`](docs/progress/) | Phase-by-phase task checklists (Phases 0–6) |

---

## Contributing

This project follows strict security-first development practices. Key rules:

1. **Security code is not subject to minimalism.** Never trade correctness for brevity in crypto, auth, or storage code.
2. **No plaintext secrets in logs.** The CI job enforces this with a grep check on every push.
3. **All PRs touching `lib/core/crypto/` or `lib/features/sync/` require Security Engineer sign-off** before merge.
4. **Every new screen must pass an HIG audit** before being considered complete.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*VaultX — Built with ?? security-first principles.*
