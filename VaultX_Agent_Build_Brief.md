# VaultX — Senior Agent Build Brief (v2)
**Target runtime:** Antigravity CLI (`agy`), Gemini 3.8 Flash
**Your role:** You are the executing agent. I am the senior engineer who wrote this brief; treat every instruction below as coming directly from me, not as background reading. You act as orchestrator across the phases — assigning sub-agent/sub-task context per phase where your host supports it, reviewing your own diffs, and running tests yourself before marking anything done.

---

## 0. Reality check — read this before you plan anything

1. **You cannot build all four target platforms from one machine.** iOS and macOS builds require Xcode on real Apple hardware. Windows desktop builds require Windows with Visual Studio Build Tools installed. Only Android cross-compiles from anywhere. If you are running on a single OS, do not attempt to locally build the platforms that OS can't support — set up a CI matrix instead (GitHub Actions with `macos-latest`, `windows-latest`, `ubuntu-latest` runners is the standard solution) and treat CI-green as the actual exit criterion for "builds on all 4 platforms." Never report a platform as building successfully unless you have direct evidence (a local build log or a CI run) for that specific platform — don't infer it from the others compiling.
2. **This project's branding has drifted across three names**: "Sentinel Core" (design-file metadata), "VaultX" (on-screen wordmark in the original export), "VaultX" (used in later planning). Pick exactly one in Phase 0 and use it everywhere — package IDs, bundle identifiers, repo name, user-facing strings.
3. **Security code is not subject to minimalism pressure.** If you install the `ponytail` skill (recommended below) for lean implementation, its own rules already exempt validation, encryption, auth, and accessibility from the "delete this" instinct — but confirm that exemption yourself before Phase 2, don't assume.

---

## 1. Working method — mandatory for every phase, not just Phase 0

- **Before writing any implementation code for a phase, produce an explicit numbered todo list for that phase specifically** (not a project-wide list). If your host has a native task/todo tracking tool, use it. If not, write it to `docs/progress/phase-N-todo.md` as a markdown checklist. Do not start implementation before this file/list exists.
- Check items off as you actually complete them — no batch-completing everything at the end of a phase.
- Before declaring a phase done, re-read your own todo list against what you actually built. Anything skipped either gets done or gets logged with a reason in `docs/design-decisions.md` — it does not just silently disappear.
- If you hit a genuine ambiguity this brief doesn't resolve, make the most reasonable call and keep moving — but write the assumption down in `docs/design-decisions.md` so I can correct it if you guessed wrong. Don't stall waiting for clarification on small things; do stop and ask me directly if the ambiguity is about security architecture, data loss risk, or which brand name to use.
- The seed checklists under each phase below are a **starting point, not a replacement** for your own todo list — expand them with the actual sub-tasks your implementation needs.

---

## 2. What this app is

A **local-first, offline-capable password and card vault**, Flutter-based, targeting Android, iOS, Windows, and macOS (Linux/Web are optional stretch targets, don't let them block the four primary ones).

Core promise to the user: vault data is encrypted at rest, unlockable by biometric or master password, and never leaves their devices in plaintext — including during sync.

Priority order when anything conflicts: **1) security correctness, 2) cross-platform consistency, 3) it actually builds and passes its own tests before a phase is marked complete, 4) feature completeness.**

---

## 3. Tech stack (decided — don't re-litigate per phase)

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter (stable channel) | Single codebase, native compilation on all 4 targets |
| State management | Riverpod | Testable, no BuildContext-coupled singletons |
| Local storage (metadata/index) | `drift` (SQLite) for the encrypted-blob index | Queryable, identical on all platforms |
| Secret-at-rest storage | `flutter_secure_storage` (Keychain / DPAPI+Credential Locker / Android Keystore) — for the *master key only*, never the vault blob | Hardware-backed where available |
| Vault encryption | AES-256-GCM via `cryptography` or `pointycastle` | Authenticated encryption; never a custom cipher |
| Key derivation | Argon2id (via `cryptography` or `sodium_libs`/libsodium bindings) from master password + per-install salt | GPU-resistant, unlike PBKDF2 |
| Biometric gate | `local_auth` | Gates access to the derived key, doesn't replace the KDF |
| LAN discovery | `bonsoir` or `nsd` (mDNS/Bonjour/DNS-SD) | Same-network device discovery, no server needed |
| LAN transfer | `web_socket_channel` | Works identically on all 4 platforms |
| Cross-network fallback | Small relay you control, WSS/443 | Passes through almost all NATs/firewalls by looking like ordinary HTTPS |
| Pairing handshake | X25519 ECDH, verification code derived from exchanged keys | See §6.2 — this is the corrected version of an earlier flawed design, don't revert to an independent PIN |
| QR generation/scan | `qr_flutter` + `mobile_scanner` | Mature, maintained |
| Testing | `flutter_test` + `integration_test` + `mocktail` | Standard Flutter stack |

**Explicitly rejected:** custom sync protocol, custom crypto primitives, treating the QR/PIN value itself as an encryption key.

---

## 4. Skills to load before Phase 1

```bash
# Apple HIG cross-platform design reviewer — no native Antigravity installer exists for this one,
# so fetch it directly instead of relying on an install command.
git clone https://github.com/dickwu/apple-design-skill.git .design-rules
# If you can't clone, web-fetch these directly:
#   https://raw.githubusercontent.com/dickwu/apple-design-skill/main/SKILL.md          (review process, audit framework)
#   https://raw.githubusercontent.com/dickwu/apple-design-skill/main/references/hig-lookup.md   (topic -> file routing table)
# Then fetch only the specific references/hig/<topic>.md files hig-lookup.md points you to per screen —
# not all 53 up front. At minimum: color.md, dark-mode.md, typography.md, layout.md, accessibility.md,
# plus gestures.md for anything interactive (the swipe-to-create control, the QR scanner view).

# Anti-overengineering ruleset — has a documented Antigravity CLI path, use the real command:
agy plugin install https://github.com/DietrichGebert/ponytail
# Its commands become chat-typed messages under Antigravity (e.g. type "/ponytail-review" as a message,
# don't look for it in a slash menu). Confirm security-code exemption per §0.3 before Phase 2.

# Official Flutter/Dart team skill repos — treat as your primary Flutter API reference, not memory:
git clone https://github.com/flutter/agent-plugins.git .flutter-rules
git clone https://github.com/dart-lang/skills.git .dart-rules

# Community skill with a testing + security focus specifically for Flutter — load its SKILL.md:
# https://github.com/Harishwarrior/flutter-claude-skills  (flutter-tester: unit/widget/integration, mocking, security patterns)

# Comprehensive Flutter/Dart reference pack (Material 3, testing, 19 reference files) for API accuracy
# on a fast-moving framework:
# https://github.com/Arcturus91/claude-flutter-skill
```

Use a higher `thinking_level` for Phase 2 (crypto/key management) and Phase 4 (sync protocol) — a rushed answer there is a real vulnerability, not a bug you fix later. Default/low is fine for Phase 1 scaffolding and Phase 3 UI wiring.

---

## 5. Agent roles

- **Architect** — owns §3 decisions, project scaffolding, module boundaries.
- **Security Engineer** — owns §6 in full. Veto power over any PR touching secrets, storage, or the network layer.
- **UI/Design Agent** — implements the 8 screens, gated by an `apple-design-skill` review before a screen counts as done.
- **Sync/Networking Agent** — owns §6.2 end to end.
- **QA/Test Agent** — writes and independently re-runs tests for every other role's output. Never tests its own feature.
- **You (Orchestrator)** — sequences phases, resolves cross-role conflicts, is the only one who marks a phase done in the tracker.

---

## 6. Security architecture (Security Engineer owns; no other role edits without sign-off)

### 6.1 At rest
- Master password (or biometric-gated equivalent) → Argon2id → 256-bit master key. Never store the master password itself, anywhere — not in logs, not in crash reports, not in memory longer than needed.
- Master key lives only in the platform secure enclave, gated by biometric re-auth on cold start and after a configurable idle timeout.
- Every vault entry is encrypted individually with AES-256-GCM under a key derived from the master key — never one static key/IV for the whole database.
- No plaintext vault data touches disk, swap, or a crash log. CI greps for accidental `print`/`log` of decrypted fields.

### 6.2 Sync (device-to-device) — corrected design, do not revert
1. **Discovery:** mDNS on LAN; relay by account/session ID when not on the same LAN.
2. **Connection info via QR:** the offering device opens a local WebSocket listener and encodes local IP, port, and a short-lived session ID in a QR (plus manual-entry fallback). Pure rendezvous — no cryptographic weight here.
3. **Key exchange:** ephemeral X25519 keypair per device, ECDH over that connection to derive a shared secret.
4. **Verification code must be derived, never independent:** the 6-digit code shown on both screens is a hash of both devices' exchanged public keys (or the derived shared secret), truncated to 6 digits — same pattern as Signal's safety numbers / Bluetooth Numeric Comparison. An independently-generated PIN transmitted alongside the connection info gives zero MITM protection — don't build it that way.
5. User taps to confirm the two codes match before either device accepts pairing.
6. **Session encryption:** HKDF from the shared secret → AES-256-GCM per message, LAN or relay. The relay only ever forwards ciphertext.
7. **Session hygiene:** pairing session expires after 60 seconds, verification code is single-use, master password/master key never appears in the QR payload, verification code, or any sync message.
8. **Sync logic:** last-write-wins per field via vector clock/timestamp, merge in only entries missing on the receiving device, never clobber a newer local edit with an older synced one, surface conflicts to the user.
9. **Relay stays required, not optional** — same-network-only would not meet the original cross-network requirement. Only drop it if I tell you to explicitly.
10. WSS/443 for the relay passes through most firewalls/VPNs by looking like ordinary HTTPS. It is not a guarantee against a network deliberately configured to block it.

### 6.3 Threat model must-haves
- Wipe/lockout after N failed unlock attempts (configurable).
- No recovery path that reintroduces a plaintext backdoor — decide and document whether "forgot master password" means data loss by design or a user-exported recovery key.
- Dependency vulnerability scan as a CI step before each release build.

---

## 7. Design directive

- Apple HIG principles (via the loaded skill) translated to Material 3 widgets — not a literal Cupertino skin. Use the skill's cross-platform translation table so each OS gets idiomatic chrome while sharing one token set.
- Both light and dark themes are mandatory from day one, built as paired `ColorScheme`s — not dark-first with light bolted on later.
- Reuse the token set already reverse-engineered from the original export as the dark theme baseline: background `#020617`, primary `#0080ff`, card surface `#191c1e`, Hanken Grotesk/Inter/JetBrains Mono type scale, `emerald-500`/`amber-500`/`rose-500` status colors, fully-rounded pills for buttons/nav/chips. Derive light theme from the same semantic roles, not by inverting hex values by hand.
- Every finished screen runs through the apple-design-skill audit before being marked done. Contrast/accessibility findings are not optional polish for a password manager.

---

## 8. Phase plan — detailed, with seed checklists

Each phase's checklist below is a **starting point**. Expand it into your own numbered todo list per §1 before writing code.

### Phase 0 — Ingestion & decisions (Owner: Orchestrator)
- [ ] Confirm the zip is extracted; extract it if not
- [ ] Read every screen's `code.html` + `screen.png` together — code is ground truth, screenshot is reference only
- [ ] Cross-check `DESIGN.md` frontmatter against rendered `code.html` values; log every conflict found
- [ ] Resolve the brand name (§0.2) and record the decision + reasoning
- [ ] Produce `docs/design-audit.md` — one entry per screen: purpose, components, colors actually used, inconsistencies found
- [ ] Produce `docs/design-decisions.md` — every conflict and how it was resolved
- [ ] Stop and present both docs to me before starting Phase 1

**Exit criteria:** both docs exist, every discrepancy from §0 is logged, brand name is decided.

### Phase 1 — Project scaffold & CI (Owner: Architect)
- [ ] `flutter create` targeting android, ios, windows, macos
- [ ] Feature-first folder structure: `lib/features/{vault,wallet,auth,sync,settings}`, `lib/core/{crypto,storage,theme}`
- [ ] Add and pin every dependency from §3 to `pubspec.yaml`
- [ ] Set up CI as a **matrix** (per §0.1) with a job per platform — this is how "builds on all 4 platforms" gets verified, not a local build
- [ ] Add lint rules (`flutter_lints` or stricter) plus the print/log-of-secrets grep check (refined properly in Phase 2)
- [ ] Confirm an empty app actually builds green in every CI job, with the log/run linked as evidence

**Exit criteria:** CI matrix green on all 4 platforms with linked evidence per platform, not an assumption.

### Phase 2 — Security core (Owner: Security Engineer, high thinking level)
- [ ] Argon2id key derivation from master password + per-install random salt
- [ ] Master key stored only via `flutter_secure_storage`
- [ ] `local_auth` biometric gate in front of key retrieval
- [ ] AES-256-GCM encrypt/decrypt per vault entry, unique nonce per entry, never reused
- [ ] Failed-attempt counter + lockout/wipe policy
- [ ] Unit tests: KDF determinism + salt uniqueness, encrypt/decrypt round-trip, GCM tamper detection, lockout triggers at threshold
- [ ] Run the print/log grep check against this code specifically — zero hits required
- [ ] Document the "forgot master password" decision in `docs/design-decisions.md`

**Exit criteria:** all listed tests green, zero plaintext-logging hits, recovery-path decision documented.

### Phase 3 — Screens & theming (Owner: UI/Design Agent)
Seed list — all 8 must appear in your own todo list, one row each:
- [ ] Login / Sign Up
- [ ] Passwords Vault (home)
- [ ] Add Password
- [ ] Edit Password
- [ ] Password Generator
- [ ] Digital Wallet
- [ ] Add Card
- [ ] Settings / Theme Switcher

Per screen: build widget → wire to Riverpod → implement both themes → fetch the relevant `references/hig/*.md` via `hig-lookup.md` routing (color + dark-mode + accessibility at minimum, plus layout/gestures for interactive screens) → run the audit → fix flagged issues → write a widget test.

**Exit criteria:** all 8 screens built and themed both ways, zero unresolved high-severity HIG findings, one widget test per screen green.

### Phase 4 — Sync & pairing (Owner: Sync/Networking Agent, high thinking level)
- [ ] mDNS advertise/discover
- [ ] Local WebSocket listener + QR payload encode/decode (IP, port, session ID)
- [ ] X25519 ephemeral keypair + ECDH per session
- [ ] Verification code derived from exchanged keys per §6.2.4 — not independently generated
- [ ] User-confirmation UI for the code match
- [ ] HKDF session key → AES-256-GCM message encryption
- [ ] 60-second session expiry, single-use verification code
- [ ] Relay client (WSS/443) as the fallback path when LAN discovery fails or times out
- [ ] Merge logic: timestamp/vector-clock based, add-missing without clobbering newer local edits, conflicts surfaced to the user
- [ ] Integration test: two in-process mock devices complete pair → sync → merge, with an assertion that only ciphertext ever crosses the mocked transport boundary (assert at the socket/message layer, not just "at rest")

**Exit criteria:** integration test green; at least one manual same-network test between two real devices; relay path exercised at least once across two different networks.

### Phase 5 — QA & security verification (Owner: QA/Test Agent)
- [ ] Independently re-run every unit/widget/integration test from Phases 1–4 — don't trust a prior "it passed," rerun it yourself
- [ ] Walk §6.3 item by item, mark pass/fail with evidence
- [ ] Negative-test the pairing flow: expired session, reused verification code, malformed QR payload, deliberately wrong code
- [ ] Dependency vulnerability scan
- [ ] Accessibility pass beyond what the HIG audit already caught (screen reader labels, focus order, contrast)

**Exit criteria:** everything above green, or explicitly triaged with a logged reason and my sign-off.

### Phase 6 — Packaging (Owner: Orchestrator + all)
- [ ] Android: signed AAB/APK
- [ ] iOS: IPA — **flag immediately, don't silently skip,** if no Apple Developer account/provisioning profile/macOS signing environment is available to you
- [ ] Windows: MSIX or portable installer
- [ ] macOS: signed `.app`/`.dmg` — **flag immediately** if notarization credentials aren't available
- [ ] README covering setup + architecture
- [ ] Finalize `docs/design-decisions.md` as the permanent record

**Exit criteria:** an installable artifact per platform you actually had the credentials/environment to produce, with any platform you couldn't complete clearly flagged to me rather than silently marked done.

---

## 9. Definition of done

- [ ] CI-verified build evidence for all 4 platforms (not assumed from one platform succeeding)
- [ ] Light and dark themes both fully implemented
- [ ] Every screen passed an apple-design-skill audit
- [ ] AES-256-GCM at rest, Argon2id-derived key, hardware-backed key storage
- [ ] Zero plaintext secrets in logs/crash reports (enforced by test)
- [ ] Pairing uses ECDH + key-derived verification code, never an independent PIN
- [ ] LAN sync works standalone; relay fallback works over WSS/443
- [ ] Sync merges missing entries without clobbering newer local edits
- [ ] Failed-unlock lockout implemented and tested
- [ ] Full test suite independently re-verified by the QA role, green on every platform
- [ ] One canonical brand name used everywhere
- [ ] `docs/design-decisions.md` documents every conflict resolved and every assumption made along the way

---

## 10. Kickoff prompt — paste this in first

> You are the Architect and Security Engineer for this Flutter password/card vault (final name to be decided in Phase 0 — see §0.2), targeting Android, iOS, Windows, and macOS. Read this entire brief before writing any code or making any plan. Your first action is not code — it is Phase 0: extract the provided zip if not already extracted, read every `code.html` alongside its `screen.png`, cross-check against `sentinel_core/DESIGN.md`'s frontmatter, resolve the brand name, and produce `docs/design-audit.md` and `docs/design-decisions.md` exactly as specified in §8 Phase 0. Before you touch any of that, write your Phase 0 todo list per §1 and show it to me. Do not proceed to Phase 1 until I've reviewed the Phase 0 output.
