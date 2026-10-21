# VaultX — Design & Architecture Decisions (Phase 0)

**Date:** 2026-09-07  
**Status:** Approved for Review  
**Owners:** Orchestrator / Architect & Security Engineer  

---

## 1. Canonical Brand Name Resolution (§0.2)

### Context & Historical Drift
During planning and design export, the project branding drifted across three disparate names:
1. **"Sentinel Core"**: Appeared exclusively in design-file metadata (`sentinel_core/DESIGN.md` line 2: `name: Sentinel Core`). Never used in user-facing UI copy.
2. **"VaultX"**: The explicit on-screen wordmark rendered on Screen 1 (`login_sign_up`) hero section (`<span class="text-gradient">VaultX</span>`), accompanied by the slogan *"Your mind, secured."* Used in page titles (`<title>View & Edit Password - VaultX</title>`) and data storage namespaces (`VaultX_theme`, `VaultX_vault_passwords`, `VaultX_wallet_cards`). Also matches the title of this build brief: `VaultX — Senior Agent Build Brief (v2)`.
3. **"VaultX"**: Used as the host folder and repo placeholder name during early scaffolding (`D:\VaultX\vault_X`).

### Decision
The single canonical brand name is **VaultX**.
- **Display Name (User-facing):** `VaultX`
- **Application Package / Bundle ID:** `com.VaultX.vault`
- **Flutter Project / Pubspec Name:** `VaultX`
- **Repository Root:** `VaultX` (aliased in current workspace)
- **Data Namespace:** `VaultX_*`
- **All User-Facing Copy:** Always `VaultX`. "Sentinel Core" and "VaultX" are retired from all customer-facing surfaces and code references.

---

## 2. Design Token System Reconciliation

### The Discrepancy
`sentinel_core/DESIGN.md` contained conflicting specifications:
- The YAML frontmatter specified a low-contrast pastel Material 3 scheme (`primary: #bec6e0`, `secondary: #a9c7ff`, `surface: #101415`).
- The Markdown body text specified a different palette (`Primary Navy: #0F172A`, `Secondary Vibrant Blue: #0084ff`, `Surface: #1E293B`).
- The actual HTML/CSS code across all 8 screens implemented a deep OLED black/navy baseline (`#020617` / `#000000`), vibrant electric blue `#0080ff` for interactive CTAs, switches, and active navigation items, paired with emerald green (`#10b981`), amber (`#f59e0b`), and rose red (`#ef4444`) functional accents.

### Decision
The actual rendered code in `code.html` is the ground truth. We adopt the reverse-engineered token set from the export as the dark theme baseline and pair it with a light theme derived from semantic roles:

#### Dark Theme Baseline (`ColorScheme.dark()`)
- **Background / Scaffold:** `#020617` (Deepest Obsidian Slate)
- **Surface / Card Container:** `#191c1e` (Dark Surface Container)
- **Surface High / Elevated Inputs:** `#272a2c` / `#1e293b`
- **Primary Accent:** `#0080ff` (Vibrant Electric Blue)
- **Primary Container / Floating Elements:** `#1a1d20`
- **Secondary Accent:** `#a855f7` (Violet gradient accent for logo/branding)
- **Success / Healthy:** `#10b981` (Emerald 500)
- **Warning:** `#f59e0b` (Amber 500)
- **Danger / Error:** `#ef4444` (Rose Red 500)
- **Text On Surface:** `#f8fafc` (High Contrast White)
- **Text On Surface Variant (Muted):** `#94a3b8` / `#8b949e`
- **Border / Outline:** `rgba(255, 255, 255, 0.08)` (Subtle border for cards/dividers)

#### Paired Light Theme Baseline (`ColorScheme.light()`)
Derived directly from the reverse-engineered light theme in `settings_theme_switcher/code.html` (lines 66–158):
- **Background / Scaffold:** `#f8fafc` (Clean Slate Light)
- **Surface / Card Container:** `#ffffff` (Pure White Card)
- **Surface High / Elevated Inputs:** `#f1f5f9` (Light Slate Input fill)
- **Primary Accent:** `#0080ff` (Identical Vibrant Electric Blue for brand consistency)
- **Text On Surface:** `#0f172a` (Deep Slate Text)
- **Text On Surface Variant (Muted):** `#64748b` (Slate Gray)
- **Border / Outline:** `#e2e8f0` (Light Border)
- **Success / Warning / Error:** Shared semantic tokens (`#10b981`, `#f59e0b`, `#ef4444`)

#### Shape & Geometry Tokens
- **Pill Buttons & Navigation Dock:** Fully rounded (`BorderRadius.circular(9999)` / pill capsule).
- **Cards & Dialog Containers:** Rounded-2xl (`BorderRadius.circular(16)` to `24`).
- **Input Fields:** Rounded-xl (`BorderRadius.circular(12)` to `16`).

#### Typography Scale
- **Headlines:** Hanken Grotesk (700 Bold / 600 SemiBold)
- **Body & Controls:** Inter (400 Regular, 500 Medium, 600 SemiBold)
- **Monospace Data (Passwords, Card Numbers, URLs, PINs, Keys):** JetBrains Mono (500 Medium)

---

## 3. "Forgot Master Password" Security Architecture Decision (§6.3)

### The Security Dilemma
In a zero-knowledge local-first vault, vault records are encrypted at rest with keys derived via Argon2id from the user's master password. If the master password is forgotten, any cloud-based "password reset" mechanism would require storing an escrow decryption key on a remote server—violating the core promise that data never leaves the device in plaintext and has no backdoor.

### Decision
1. **No Backdoor by Design:** There is no server-assisted password recovery or magic link.
2. **User-Exported Recovery Key:**
   - During account onboarding or initial vault setup, the user is presented with a cryptographically generated, high-entropy Recovery Key (BIP-39 style 24-word seed phrase or a formatted 256-bit hexadecimal string, formatted in JetBrains Mono).
   - The user is required to confirm they have saved this key offline (e.g., written down or printed).
   - The recovery key encrypts a copy of the vault master key independently.
3. **Data Loss on Total Loss:**
   - If both the Master Password and the Recovery Key are lost, **vault data is permanently unrecoverable by design**.
   - The user is provided with a "Wipe All Data & Reset Vault" option to start fresh, as reflected in the Danger Zone of `settings_theme_switcher`.
   - This prevents brute-force or unauthorized access by third parties.

---

## 4. Cryptographic Implementation Architecture (§6.1, §6.2)

1. **Key Derivation Function (KDF):**
   - Argon2id with 256-bit output.
   - Salt: 16-byte cryptographically secure random salt generated per-installation and stored in local database metadata.
   - Parameters tuned to OWASP recommendations: memory 64MB, iterations 3, parallelism 1.
2. **Key Storage at Rest:**
   - The master key is stored strictly via `flutter_secure_storage` (backed by iOS Keychain, Android Keystore, Windows DPAPI / Credential Locker, macOS Keychain).
   - The master password itself is never stored on disk, in swap, or logged.
   - Biometric access (`local_auth`) gates retrieval of the master key from the platform secure enclave.
3. **Vault Blob Encryption:**
   - AES-256-GCM.
   - Each vault record (passwords, cards, secure notes) is encrypted individually with a distinct 96-bit (12-byte) initialization vector (IV/nonce) generated randomly for every write. Nonces are never reused.
4. **Device-to-Device Sync Handshake (§6.2):**
   - Discovery: mDNS via `bonsoir` on local Wi-Fi / LAN.
   - Rendezvous: Local WebSocket listener with connection info encoded into a QR payload (IP, port, session ID).
   - Ephemeral Key Exchange: X25519 ECDH keypair generated per session.
   - Key-Derived Verification Code: 6-digit numeric comparison code derived by hashing both public keys (`SHA-256(pubKeyA || pubKeyB)` truncated to 6 digits). **Never** an independently transmitted PIN.
   - Session Key: Derived via HKDF from the ECDH shared secret -> AES-256-GCM session messages.
   - Relay Fallback: WSS/443 relay server forwarding ciphertext only, used when direct LAN connection is blocked.

---

## 5. Multi-Platform Build & CI Matrix Reality (§0.1)

### The Cross-Platform Constraint
- Local development host is Windows.
- iOS and macOS builds strictly require macOS runners with Xcode and Apple developer toolchains.
- Attempting to claim macOS/iOS compilation on Windows is invalid.

### Decision & Validation Strategy
1. **Local Host Testing:** Local compilation, Flutter unit tests, widget tests, and Windows desktop build will be validated directly on the host machine.
2. **Cross-Platform Verification via GitHub Actions CI Matrix:**
   - Create `.github/workflows/ci.yml` defining a matrix across:
     - `macos-latest` (iOS build & macOS desktop build)
     - `windows-latest` (Windows desktop build)
     - `ubuntu-latest` (Android APK/AAB build & headless test execution)
   - Exit criterion for "builds on all 4 platforms" requires green CI runs or concrete build logs, not inferences.

---

## 6. Phase 6 Packaging � Platform Artifact Decisions

**Date updated:** 2026-09-12

### Android
- **Decision:** CI (`ubuntu-latest`) produces a debug APK and a debug AAB on every push as downloadable GitHub Actions artifacts.
- **Release signing flag:** Production-signed APK/AAB requires an Android keystore. No keystore is available in this environment; the CI workflow is prepared for signing (gradle config in place) but the signing step is documented as a post-environment credential step. The build brief exit criterion of "an installable artifact" is satisfied by the debug APK artifact.

### iOS
- **FLAG (per Phase 6 brief �8):** iOS packaging requires macOS + Xcode + Apple Developer Program membership with a provisioning profile and distribution certificate. **This environment runs Windows.** A signed `.ipa` cannot be produced locally or without credentials.
- **Decision:** CI (`macos-latest`) performs `flutter build ios --no-codesign --debug` (simulator build) as compilation evidence per �0.1. The no-codesign build artifact is uploaded. This is the maximum that can be produced without Apple Developer credentials. This limitation is explicitly flagged here and in the README � it is not silently skipped.

### Windows
- **Decision:** CI (`windows-latest`) produces a Windows debug executable artifact. Locally, `flutter build windows --debug` succeeds; release mode requires Developer Mode (symlink support) which requires elevated system privileges not available in this agent environment.
- **MSIX packaging:** Not implemented in this phase � MSIX requires a code signing certificate. The portable exe build (debug) serves as the installable artifact. MSIX production packaging is logged as a post-credential step.

### macOS
- **FLAG (per Phase 6 brief �8):** macOS `.app` notarization requires Apple Developer credentials and code signing certificates. **The host machine is Windows.**
- **Decision:** CI (`macos-latest`) produces an unsigned macOS `.app` via `flutter build macos --debug` as compilation evidence. This is uploaded as a CI artifact. Notarization is documented as requiring explicit Apple Developer credentials � not silently skipped.

### Summary � Artifacts Produced
| Platform | Artifact | Source | Signed? |
|---|---|---|---|
| Android | `app-debug.apk`, `app-debug.aab` | CI `ubuntu-latest` | No (debug) � release signing is a credential step |
| iOS | `.app` (no-codesign simulator) | CI `macos-latest` | No � Apple Developer credentials required |
| Windows | `VaultX.exe` + DLLs | CI `windows-latest` | No (debug) � MSIX signing is a credential step |
| macOS | `VaultX.app` (unsigned) | CI `macos-latest` | No � notarization requires Apple credentials |
