import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/crypto/vault_cipher.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/features/sync/data/sync_client.dart';
import 'package:vaultx/features/sync/data/sync_server.dart';
import 'package:vaultx/features/sync/domain/sync_crypto_service.dart';
import 'package:vaultx/features/sync/domain/sync_protocol_models.dart';
import 'package:vaultx/features/sync/domain/vault_merge_engine.dart';
import 'package:vaultx/features/sync/presentation/providers/sync_provider.dart';
import 'package:vaultx/features/sync/presentation/sync_screen.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncCryptoService & Key Exchange Tests', () {
    late SyncCryptoService cryptoService;

    setUp(() {
      cryptoService = SyncCryptoService();
    });

    test('ECDH agreement: Two ephemeral keypairs compute identical shared secret', () async {
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();

      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);

      expect(pubA.length, equals(32));
      expect(pubB.length, equals(32));

      final sharedSecretA = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubB,
      );

      final sharedSecretB = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairB,
        remotePublicKeyBytes: pubA,
      );

      final bytesA = await sharedSecretA.extractBytes();
      final bytesB = await sharedSecretB.extractBytes();

      expect(bytesA, equals(bytesB));
    });

    test('Verification code derivation: Both devices derive identical 6-digit code (§6.2.4)', () async {
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();

      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);

      final sharedSecretA = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubB,
      );

      final sharedSecretB = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairB,
        remotePublicKeyBytes: pubA,
      );

      // Device A computes code
      final codeA = await cryptoService.deriveVerificationCode(
        localPublicKeyBytes: pubA,
        remotePublicKeyBytes: pubB,
        sharedSecret: sharedSecretA,
      );

      // Device B computes code
      final codeB = await cryptoService.deriveVerificationCode(
        localPublicKeyBytes: pubB,
        remotePublicKeyBytes: pubA,
        sharedSecret: sharedSecretB,
      );

      expect(codeA.length, equals(6));
      expect(codeB.length, equals(6));
      expect(codeA, equals(codeB));
      expect(int.tryParse(codeA), isNotNull);
    });

    test('MITM protection: Discrepant keypair results in different verification codes', () async {
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();
      final keyPairMitm = await cryptoService.generateEphemeralKeyPair();

      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);
      final pubMitm = await cryptoService.extractPublicKeyBytes(keyPairMitm);

      final sharedSecretA = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubMitm,
      );
      final sharedSecretB = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairB,
        remotePublicKeyBytes: pubA,
      );

      final codeA = await cryptoService.deriveVerificationCode(
        localPublicKeyBytes: pubA,
        remotePublicKeyBytes: pubMitm,
        sharedSecret: sharedSecretA,
      );

      final codeB = await cryptoService.deriveVerificationCode(
        localPublicKeyBytes: pubB,
        remotePublicKeyBytes: pubA,
        sharedSecret: sharedSecretB,
      );

      expect(codeA, isNot(equals(codeB)));
    });

    test('HKDF session key agreement: Both endpoints derive identical AES-256 session key', () async {
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();

      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);

      final sharedSecretA = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubB,
      );
      final sharedSecretB = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairB,
        remotePublicKeyBytes: pubA,
      );

      final sessionKeyA = await cryptoService.deriveSessionKey(
        localPublicKeyBytes: pubA,
        remotePublicKeyBytes: pubB,
        sharedSecret: sharedSecretA,
      );
      final sessionKeyB = await cryptoService.deriveSessionKey(
        localPublicKeyBytes: pubB,
        remotePublicKeyBytes: pubA,
        sharedSecret: sharedSecretB,
      );

      final bytesA = await sessionKeyA.extractBytes();
      final bytesB = await sessionKeyB.extractBytes();

      expect(bytesA, equals(bytesB));
      expect(bytesA.length, equals(32));
    });

    test('Session encryption & decryption roundtrip with fresh random IVs', () async {
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();
      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);
      final sharedSecret = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubB,
      );
      final sessionKey = await cryptoService.deriveSessionKey(
        localPublicKeyBytes: pubA,
        remotePublicKeyBytes: pubB,
        sharedSecret: sharedSecret,
      );

      const secretPayload = '{"password":"super_secret_password_123","service":"GitHub"}';

      final record1 = await cryptoService.encryptMessage(
        cleartextJson: secretPayload,
        sessionKey: sessionKey,
      );
      final record2 = await cryptoService.encryptMessage(
        cleartextJson: secretPayload,
        sessionKey: sessionKey,
      );

      // Nonces must be unique across encryptions
      expect(record1.nonce, isNot(equals(record2.nonce)));

      final decrypted1 = await cryptoService.decryptMessage(
        record: record1,
        sessionKey: sessionKey,
      );
      expect(decrypted1, equals(secretPayload));
    });

    test('Tampered ciphertext throws TamperedCiphertextException', () async {
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();
      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);
      final sharedSecret = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubB,
      );
      final sessionKey = await cryptoService.deriveSessionKey(
        localPublicKeyBytes: pubA,
        remotePublicKeyBytes: pubB,
        sharedSecret: sharedSecret,
      );

      final record = await cryptoService.encryptMessage(
        cleartextJson: '{"token":"valid"}',
        sessionKey: sessionKey,
      );

      // Tamper with first byte of ciphertext
      final tamperedCiphertext = List<int>.from(record.ciphertext);
      tamperedCiphertext[0] ^= 0xFF;

      final tamperedRecord = EncryptedRecord(
        nonce: record.nonce,
        ciphertext: tamperedCiphertext,
        mac: record.mac,
      );

      expect(
        () async => await cryptoService.decryptMessage(
          record: tamperedRecord,
          sessionKey: sessionKey,
        ),
        throwsA(isA<TamperedCiphertextException>()),
      );
    });
  });

  group('VaultMergeEngine Tests (§6.2.8)', () {
    late VaultMergeEngine engine;

    setUp(() {
      engine = VaultMergeEngine();
    });

    test('Adds missing remote entries to local vault', () {
      final local = [
        VaultPasswordEntry(
          id: 'pw-1',
          title: 'Google',
          username: 'user@gmail.com',
          password: 'pass1',
          category: 'Email',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      ];

      final incoming = [
        VaultPasswordEntry(
          id: 'pw-2',
          title: 'GitHub',
          username: 'dev@github.com',
          password: 'pass2',
          category: 'Development',
          createdAt: DateTime(2025, 1, 2),
          updatedAt: DateTime(2025, 1, 2),
        ),
      ];

      final report = engine.merge(
        localPasswords: local,
        incomingPasswords: incoming,
        localCards: [],
        incomingCards: [],
      );

      expect(report.passwordsInserted, equals(1));
      expect(report.mergedPasswords.length, equals(2));
      expect(report.mergedPasswords.map((p) => p.id), containsAll(['pw-1', 'pw-2']));
    });

    test('LWW: Newer remote edit overwrites older local entry', () {
      final local = [
        VaultPasswordEntry(
          id: 'pw-1',
          title: 'Google',
          username: 'old@gmail.com',
          password: 'old_password',
          category: 'Email',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      ];

      final incoming = [
        VaultPasswordEntry(
          id: 'pw-1',
          title: 'Google',
          username: 'new@gmail.com',
          password: 'new_password',
          category: 'Email',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 10), // Newer
        ),
      ];

      final report = engine.merge(
        localPasswords: local,
        incomingPasswords: incoming,
        localCards: [],
        incomingCards: [],
      );

      expect(report.passwordsUpdated, equals(1));
      final merged = report.mergedPasswords.firstWhere((p) => p.id == 'pw-1');
      expect(merged.password, equals('new_password'));
      expect(merged.username, equals('new@gmail.com'));
    });

    test('LWW: Newer local edit is preserved against older remote sync', () {
      final local = [
        VaultPasswordEntry(
          id: 'pw-1',
          title: 'Google',
          username: 'local_newest@gmail.com',
          password: 'local_password',
          category: 'Email',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 15), // Newer
        ),
      ];

      final incoming = [
        VaultPasswordEntry(
          id: 'pw-1',
          title: 'Google',
          username: 'stale_remote@gmail.com',
          password: 'stale_password',
          category: 'Email',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 10), // Older
        ),
      ];

      final report = engine.merge(
        localPasswords: local,
        incomingPasswords: incoming,
        localCards: [],
        incomingCards: [],
      );

      expect(report.passwordsPreservedLocal, equals(1));
      expect(report.passwordsUpdated, equals(0));
      final merged = report.mergedPasswords.firstWhere((p) => p.id == 'pw-1');
      expect(merged.username, equals('local_newest@gmail.com'));
    });

    test('Tombstone: Newer local deletion suppresses older remote entry (no resurrection)', () {
      final local = [
        VaultPasswordEntry(
          id: 'pw-del',
          title: 'Deleted Service',
          username: 'user@example.com',
          password: 'pass',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 15), // Deleted later
          isDeleted: true,
        ),
      ];

      final incoming = [
        VaultPasswordEntry(
          id: 'pw-del',
          title: 'Deleted Service',
          username: 'user@example.com',
          password: 'pass',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 10), // Stale active entry
          isDeleted: false,
        ),
      ];

      final report = engine.merge(
        localPasswords: local,
        incomingPasswords: incoming,
        localCards: [],
        incomingCards: [],
      );

      expect(report.mergedPasswords, isEmpty);
      expect(report.passwordsPreservedLocal, equals(1));
      expect(report.passwordsUpdated, equals(0));
    });

    test('Tombstone: Newer remote deletion propagates and removes older local entry', () {
      final local = [
        VaultPasswordEntry(
          id: 'pw-del',
          title: 'Active Locally',
          username: 'user@example.com',
          password: 'pass',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 10),
          isDeleted: false,
        ),
      ];

      final incoming = [
        VaultPasswordEntry(
          id: 'pw-del',
          title: 'Active Locally',
          username: 'user@example.com',
          password: 'pass',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 15), // Remote deleted it
          isDeleted: true,
        ),
      ];

      final report = engine.merge(
        localPasswords: local,
        incomingPasswords: incoming,
        localCards: [],
        incomingCards: [],
      );

      expect(report.mergedPasswords, isEmpty);
      expect(report.passwordsDeleted, equals(1));
    });

    test('Tombstone: Remote deleted tombstone missing locally is never inserted', () {
      final incoming = [
        VaultPasswordEntry(
          id: 'pw-unknown-del',
          title: 'Never Seen',
          username: 'user@example.com',
          password: 'pass',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 5),
          isDeleted: true,
        ),
      ];

      final report = engine.merge(
        localPasswords: [],
        incomingPasswords: incoming,
        localCards: [],
        incomingCards: [],
      );

      expect(report.mergedPasswords, isEmpty);
      expect(report.passwordsInserted, equals(0));
    });

    test('Tombstone: Newer remote edit overrides older local deletion', () {
      final local = [
        VaultPasswordEntry(
          id: 'pw-resurrect',
          title: 'Service',
          username: 'old@example.com',
          password: 'pass',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 10), // Deleted locally on Jan 10
          isDeleted: true,
        ),
      ];

      final incoming = [
        VaultPasswordEntry(
          id: 'pw-resurrect',
          title: 'Service',
          username: 'updated@example.com',
          password: 'new_pass',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 20), // Updated on remote on Jan 20
          isDeleted: false,
        ),
      ];

      final report = engine.merge(
        localPasswords: local,
        incomingPasswords: incoming,
        localCards: [],
        incomingCards: [],
      );

      expect(report.mergedPasswords.length, equals(1));
      expect(report.mergedPasswords.first.username, equals('updated@example.com'));
      expect(report.passwordsUpdated, equals(1));
    });
  });

  group('End-to-End In-Process Device Pairing & Ciphertext Transport Assertion', () {
    test('Two simulated devices pair, verify derived code, and exchange vault over encrypted wire', () async {
      final server = SyncServer(deviceName: 'Host Device');
      final client = SyncClient(deviceName: 'Client Device');

      try {
        final port = await server.start(port: 0);

        final rendezvous = SyncRendezvousPayload(
          sessionId: server.sessionId!,
          deviceName: 'Host Device',
          ipAddresses: ['127.0.0.1'],
          port: port,
        );

        // Client initiates connection
        await client.connect(rendezvous);

        // Allow handshake to settle
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Both devices must have derived matching 6-digit verification code
        expect(server.verificationCode, isNotNull);
        expect(client.verificationCode, isNotNull);
        expect(server.verificationCode, equals(client.verificationCode));
        expect(server.verificationCode!.length, equals(6));

        // Both users confirm verification code
        await server.confirmVerificationCode();
        await client.confirmVerificationCode();

        // Prepare bundles
        final hostPasswords = [
          VaultPasswordEntry(
            id: 'host-pw-1',
            title: 'Netflix',
            username: 'host@netflix.com',
            password: 'host_secret_pass',
            category: 'Entertainment',
            createdAt: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        ];

        final clientPasswords = [
          VaultPasswordEntry(
            id: 'client-pw-1',
            title: 'Spotify',
            username: 'client@spotify.com',
            password: 'client_secret_pass',
            category: 'Entertainment',
            createdAt: DateTime(2025, 1, 2),
            updatedAt: DateTime(2025, 1, 2),
          ),
        ];

        final hostBundle = SyncVaultBundle(
          passwords: hostPasswords,
          cards: [],
          exportedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
          sourceDeviceId: 'host',
        );

        final clientBundle = SyncVaultBundle(
          passwords: clientPasswords,
          cards: [],
          exportedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
          sourceDeviceId: 'client',
        );

        // Parallel exchange
        final clientFuture = client.exchangeVaultBundle(clientBundle);
        final hostFuture = server.exchangeVaultBundle(hostBundle);

        final results = await Future.wait([clientFuture, hostFuture]);
        final receivedByClient = results[0];
        final receivedByHost = results[1];

        // Verify exchanged contents
        expect(receivedByClient.passwords.first.title, equals('Netflix'));
        expect(receivedByHost.passwords.first.title, equals('Spotify'));
      } finally {
        await server.stop();
        await client.disconnect();
      }
    });

    test('Ciphertext-Only Transport Assertion: Socket wire frames NEVER contain plaintext passwords', () async {
      // Create frame with encrypted secret
      final cryptoService = SyncCryptoService();
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();
      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);
      final sharedSecret = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubB,
      );
      final sessionKey = await cryptoService.deriveSessionKey(
        localPublicKeyBytes: pubA,
        remotePublicKeyBytes: pubB,
        sharedSecret: sharedSecret,
      );

      const secretVaultData = '{"secret_password":"SUPER_CONFIDENTIAL_12345","cvv":"CONFIDENTIAL_CVV_999"}';

      final record = await cryptoService.encryptMessage(
        cleartextJson: secretVaultData,
        sessionKey: sessionKey,
      );

      final wireFrame = SyncTransportFrame.fromEncryptedRecord(
        messageType: 'data',
        record: record,
      );

      final wireString = wireFrame.toJsonString();

      // Assert that NO plaintext secret appears anywhere in the serialized transport frame
      expect(wireString.contains('SUPER_CONFIDENTIAL_12345'), isFalse);
      expect(wireString.contains('secret_password'), isFalse);
      expect(wireString.contains('CONFIDENTIAL_CVV_999'), isFalse);

      // Verify that deserialization + decryption accurately reconstructs the exact secret
      final decodedFrame = SyncTransportFrame.fromJsonString(wireString);
      final decryptedData = await cryptoService.decryptMessage(
        record: decodedFrame.toEncryptedRecord(),
        sessionKey: sessionKey,
      );

      expect(decryptedData, equals(secretVaultData));
    });

    test('Hygiene: 60-second expiry detection on SyncRendezvousPayload', () {
      final past = DateTime.now().subtract(const Duration(seconds: 1));
      final expiredPayload = SyncRendezvousPayload(
        sessionId: 'old-session',
        deviceName: 'Expired Device',
        ipAddresses: ['192.168.1.1'],
        port: 45678,
        expiresAt: past,
      );

      expect(expiredPayload.isExpired, isTrue);
    });
  });

  group('SyncScreen Widget Tests', () {
    testWidgets('renders Device Sync title and Share / Receive tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SyncScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Device Sync'), findsOneWidget);
      expect(find.text('Share Vault'), findsOneWidget);
      expect(find.text('Join / Receive'), findsOneWidget);
    });

    testWidgets('shows Code Verification View when status is codeVerification', (tester) async {
      const state = SyncOrchestrationState(
        role: SyncRole.host,
        status: SyncStatus.codeVerification,
        verificationCode: '849201',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncOrchestratorProvider.overrideWith((ref) {
              final n = SyncOrchestratorNotifier(ref);
              n.state = state;
              return n;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SyncScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verify Pairing Code'), findsOneWidget);
      expect(find.textContaining('849'), findsWidgets);
      expect(find.textContaining('Trust & Sync'), findsOneWidget);
    });
  });
}
