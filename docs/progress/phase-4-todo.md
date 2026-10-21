# Phase 4 Todo List — Sync & Pairing

**Phase:** Phase 4 — Sync & Pairing  
**Owner:** Sync/Networking Agent  
**Status:** ✅ Completed  

---

## Numbered Task Checklist

### 4.1 Cryptographic Handshake & Key Exchange Core
- [x] **4.1.1** Implement `SyncCryptoService` (`lib/features/sync/domain/sync_crypto_service.dart`):
  - [x] Ephemeral X25519 keypair generation using `cryptography`
  - [x] ECDH shared secret derivation between local private key and remote public key
  - [x] Key-derived 6-digit verification code computation (SHA-256 hash of sorted public keys + shared secret modulo 1,000,000, padded to 6 digits — Signal/Bluetooth numeric comparison model per §6.2.4)
  - [x] HKDF session key derivation (AES-256-GCM symmetric key)
  - [x] Authenticated message encryption & decryption with AES-256-GCM and fresh 12-byte random IVs per message
  - [x] Unit tests for `SyncCryptoService` (keypair generation, ECDH agreement, deterministic matching verification code on both ends, tamper detection, encryption roundtrip)

### 4.2 Protocol Messages, Rendezvous & QR Encoding
- [x] **4.2.1** Define sync protocol models (`lib/features/sync/domain/sync_protocol_models.dart`):
  - [x] `SyncRendezvousPayload`: session ID, IP addresses, port, relay URL, protocol version (pure rendezvous, no crypto keys)
  - [x] `SyncTransportMessage`: encrypted frame with type, nonce, ciphertext, auth tag, timestamp
  - [x] Protocol handshake message types: `HandshakeInit` (ephemeral pubkey), `HandshakeConfirm` (code confirmation status), `SyncPayload` (encrypted vault payload), `SyncAck`, `SyncComplete`
  - [x] 60-second session hygiene timer & single-use code tracking

### 4.3 Discovery & Transport Layer
- [x] **4.3.1** Implement `LanDiscoveryService` (`lib/features/sync/data/lan_discovery_service.dart`):
  - [x] mDNS service advertisement (`_VaultX-sync._tcp`) with Bonsoir fallback / local network binding
  - [x] mDNS discovery/browsing for nearby peers on LAN
- [x] **4.3.2** Implement `SyncServer` (`lib/features/sync/data/sync_server.dart`):
  - [x] Local WebSocket server listening on loopback / active network interface
  - [x] Handles client connection, session timeout (60s), manages ephemeral handshake
- [x] **4.3.3** Implement `SyncClient` (`lib/features/sync/data/sync_client.dart`):
  - [x] Direct LAN WebSocket client connection to `ws://<ip>:<port>`
  - [x] Fallback relay transport client connecting via WSS/443 when direct socket connection fails
  - [x] Relay client forwarding only blind encrypted payloads

### 4.4 Conflict-Free Merge Engine
- [x] **4.4.1** Implement `VaultMergeEngine` (`lib/features/sync/domain/vault_merge_engine.dart`):
  - [x] Timestamp-based Last-Write-Wins (LWW) per entry/field
  - [x] Missing entry insertion without clobbering newer local modifications
  - [x] Conflict detection logic surfacing concurrent modifications
  - [x] Card entries and Password entries unified merge pipeline
  - [x] Unit tests for merge scenarios: remote newer, local newer, concurrent edits, newly added entries, tombstoned/deleted entries

### 4.5 Riverpod State Management & Pairing Orchestration
- [x] **4.5.1** Implement `SyncOrchestratorNotifier` (`lib/features/sync/presentation/providers/sync_provider.dart`):
  - [x] States: `idle`, `advertising`, `listening`, `discovered`, `pairing`, `verifyingCode`, `syncing`, `completed`, `error`
  - [x] Host pairing workflow: start server, generate QR rendezvous, wait for peer, perform ECDH, display 6-digit code, confirm match, send encrypted vault, merge remote changes
  - [x] Client pairing workflow: scan QR / manual IP entry, connect socket, perform ECDH, display 6-digit code, confirm match, exchange encrypted payloads
  - [x] Cancellation and 60s timeout handling

### 4.6 UI / Presentation Components
- [x] **4.6.1** Implement Sync Screens & Modals (`lib/features/sync/presentation/sync_screen.dart`):
  - [x] Mode toggle: "Share / Host" vs "Receive / Join"
  - [x] Host view: QR code display (`QrImageView`), IP/Port info, active listener indicator
  - [x] Scanner / Join view: Camera QR scanner (`MobileScanner`) with manual address entry fallback
  - [x] Numeric Verification Code dialog/card: 6-digit large monospace display, "Does this code match?" confirmation buttons
  - [x] Sync progress bar and real-time status banner (Connected, Encrypting, Transferring, Merging, Finished)
  - [x] Wire Settings Screen "Sync with Devices" to open `SyncScreen`

### 4.7 Testing & Verification
- [x] **4.7.1** Unit & Integration Tests (`test/sync_pairing_test.dart`):
  - [x] Cryptographic ECDH handshake & verification code derivation unit tests
  - [x] Transport security assertion: inspect socket wire stream to verify ZERO plaintext crosses the wire (all frames are authenticated ciphertext)
  - [x] End-to-end simulated 2-device pairing: Device A (Host) and Device B (Client) establish handshake, confirm matching 6-digit code, sync, and merge entries
  - [x] Negative tests: session timeout abort, code mismatch abort, corrupted ciphertext rejection
- [x] **4.7.2** Static Analysis & Secret Check:
  - [x] `flutter analyze` -> 0 issues
  - [x] `flutter test` -> all tests green (37 unit/integration tests + 52 screen tests)
  - [x] Plaintext secret leak check (`scripts/check_secrets_log.ps1`) -> zero hits

---

## Phase 4 Exit Criteria — Verified ✅
- [x] X25519 ECDH + key-derived verification code implemented per §6.2.4 (never independent PIN)
- [x] HKDF + AES-256-GCM session encryption enforced across transport
- [x] 60-second session expiry & single-use code
- [x] Direct LAN WebSocket + WSS relay fallback path
- [x] LWW merge engine preserves newer local edits
- [x] Integration test passes asserting ciphertext-only transport wire
- [x] `flutter analyze` & `flutter test` clean
