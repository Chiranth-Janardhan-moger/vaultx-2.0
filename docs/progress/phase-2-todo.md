# Phase 2 Todo List — Security Core

**Phase:** Phase 2 — Security Core  
**Owner:** Security Engineer (High Thinking Level)  
**Status:** Completed  

---

## Numbered Task Checklist

- [x] **2.1** Implement Argon2id Key Derivation Function (`lib/core/crypto/kdf_service.dart`):
  - [x] Derive 256-bit master key using Argon2id via package `cryptography`
  - [x] Support per-install CSPRNG 16-byte random salt generation
  - [x] Support custom parameters (memory 64MB, iterations 3, parallelism 1, tag length 32)
  - [x] Ensure deterministic output for identical password + salt
- [x] **2.2** Implement Hardware-Backed Master Key Storage (`lib/core/storage/secure_key_storage.dart`):
  - [x] Store derived 256-bit master key via `flutter_secure_storage` (iOS/macOS Keychain, Android Keystore, Windows DPAPI)
  - [x] Ensure master password itself is never stored anywhere
  - [x] Provide methods to store, retrieve, check existence, and wipe the master key
- [x] **2.3** Implement Biometric Security Gate (`lib/core/crypto/biometric_auth_service.dart`):
  - [x] Gate retrieval of the master key with `local_auth`
  - [x] Check biometric availability, support Face ID, Touch ID, and platform biometrics
  - [x] Enforce fallback to master password if biometric auth fails or is disabled
- [x] **2.4** Implement Per-Entry Authenticated Encryption (`lib/core/crypto/vault_cipher.dart`):
  - [x] Use AES-256-GCM authenticated cipher
  - [x] Derive individual entry keys from master key via HKDF or sub-key derivation
  - [x] Generate a cryptographically secure fresh 96-bit (12-byte) nonce for every write operation
  - [x] Zero nonce reuse guarantee
  - [x] Authenticated tag validation: immediately throw `TamperedCiphertextException` if ciphertext or auth tag is modified
- [x] **2.5** Implement Failed Unlock Attempt Counter & Lockout/Wipe Policy (`lib/core/crypto/lockout_policy.dart`):
  - [x] Track consecutive failed unlock attempts in secure persistent storage
  - [x] Apply exponential lockout delays after 3 failed attempts
  - [x] Trigger complete cryptographic vault wipe after configurable threshold (e.g., 10 failed attempts)
  - [x] Reset counter upon successful master password authentication
- [x] **2.6** Create Comprehensive Security Unit Test Suite (`test/security_core_test.dart`):
  - [x] Test KDF determinism and per-install salt uniqueness
  - [x] Test AES-256-GCM round-trip encrypt and decrypt
  - [x] Test GCM tamper detection (modified ciphertext, altered auth tag, invalid nonce)
  - [x] Test nonce freshness assertion (generate 1,000 nonces, verify all unique)
  - [x] Test failed-attempt lockout delay escalation and wipe trigger at threshold
- [x] **2.7** Run Static Secret Leak & Plaintext Logging Grep Verification:
  - [x] Execute `scripts/check_secrets_log.ps1` targeting `lib/core/crypto` and `lib/core/storage`
  - [x] Confirm zero print/log statements exposing passwords, master keys, nonces, or plaintexts
- [x] **2.8** Update and verify `docs/design-decisions.md` with complete cryptographic specs and recovery path documentation.
