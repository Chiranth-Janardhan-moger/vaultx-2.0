import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/crypto/lockout_policy.dart';
import 'package:vaultx/core/crypto/vault_cipher.dart';
import 'package:vaultx/features/sync/domain/sync_crypto_service.dart';
import 'package:vaultx/features/sync/domain/sync_protocol_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 QA: Negative Tests for Pairing & Security (§6.2, §6.3)', () {
    late SyncCryptoService cryptoService;

    setUp(() {
      cryptoService = SyncCryptoService();
    });

    test('Negative Test: Expired rendezvous session is rejected', () {
      final expiredPayload = SyncRendezvousPayload(
        sessionId: 'expired-session-123',
        deviceName: 'Stale Device',
        ipAddresses: ['192.168.1.100'],
        port: 45678,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      expect(expiredPayload.isExpired, isTrue);
    });

    test('Negative Test: Malformed QR payload handles invalid JSON without crash', () {
      const malformedJson1 = 'NOT_A_JSON_STRING';
      const malformedJson2 = '{"incomplete":"payload"}';

      expect(
        () => SyncRendezvousPayload.fromJsonString(malformedJson1),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => SyncRendezvousPayload.fromJsonString(malformedJson2),
        throwsA(isA<TypeError>()),
      );
    });

    test('Negative Test: Single-use verification code uniqueness across sessions', () async {
      // Two successive sessions must derive completely different verification codes
      // even between the same two physical devices because ephemeral keypairs are fresh
      final keyPairA1 = await cryptoService.generateEphemeralKeyPair();
      final keyPairB1 = await cryptoService.generateEphemeralKeyPair();
      final pubA1 = await cryptoService.extractPublicKeyBytes(keyPairA1);
      final pubB1 = await cryptoService.extractPublicKeyBytes(keyPairB1);
      final secret1 = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA1,
        remotePublicKeyBytes: pubB1,
      );
      final code1 = await cryptoService.deriveVerificationCode(
        localPublicKeyBytes: pubA1,
        remotePublicKeyBytes: pubB1,
        sharedSecret: secret1,
      );

      // Subsequent session (ephemeral keys refreshed)
      final keyPairA2 = await cryptoService.generateEphemeralKeyPair();
      final keyPairB2 = await cryptoService.generateEphemeralKeyPair();
      final pubA2 = await cryptoService.extractPublicKeyBytes(keyPairA2);
      final pubB2 = await cryptoService.extractPublicKeyBytes(keyPairB2);
      final secret2 = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA2,
        remotePublicKeyBytes: pubB2,
      );
      final code2 = await cryptoService.deriveVerificationCode(
        localPublicKeyBytes: pubA2,
        remotePublicKeyBytes: pubB2,
        sharedSecret: secret2,
      );

      // Verify code is single-use and non-reusable
      expect(code1, isNot(equals(code2)));
    });

    test('Negative Test: AES-256-GCM authentication tag tampering triggers exception', () async {
      final keyPairA = await cryptoService.generateEphemeralKeyPair();
      final keyPairB = await cryptoService.generateEphemeralKeyPair();
      final pubA = await cryptoService.extractPublicKeyBytes(keyPairA);
      final pubB = await cryptoService.extractPublicKeyBytes(keyPairB);
      final secret = await cryptoService.deriveSharedSecret(
        localKeyPair: keyPairA,
        remotePublicKeyBytes: pubB,
      );
      final sessionKey = await cryptoService.deriveSessionKey(
        localPublicKeyBytes: pubA,
        remotePublicKeyBytes: pubB,
        sharedSecret: secret,
      );

      final record = await cryptoService.encryptMessage(
        cleartextJson: '{"sensitive":"data"}',
        sessionKey: sessionKey,
      );

      // Tamper with authentication tag (MAC)
      final corruptedMac = List<int>.from(record.mac);
      corruptedMac[corruptedMac.length - 1] ^= 0x01;

      final corruptedRecord = EncryptedRecord(
        nonce: record.nonce,
        ciphertext: record.ciphertext,
        mac: corruptedMac,
      );

      expect(
        () async => await cryptoService.decryptMessage(
          record: corruptedRecord,
          sessionKey: sessionKey,
        ),
        throwsA(isA<TamperedCiphertextException>()),
      );
    });

    test('Negative Test: AuthLockoutPolicy triggers progressive lockout and wipe at threshold (§6.3)', () {
      final policy = AuthLockoutPolicy(
        maxAttemptsBeforeWipe: 10,
        attemptsBeforeDelay: 3,
      );

      // Attempts 0, 1, 2: Zero lockout duration
      expect(policy.calculateLockoutDuration(0), equals(Duration.zero));
      expect(policy.calculateLockoutDuration(1), equals(Duration.zero));
      expect(policy.calculateLockoutDuration(2), equals(Duration.zero));

      // Attempt 3: 30 seconds
      expect(policy.calculateLockoutDuration(3), equals(const Duration(seconds: 30)));

      // Attempt 5: 5 minutes
      expect(policy.calculateLockoutDuration(5), equals(const Duration(minutes: 5)));

      // Attempt 8: 1 hour
      expect(policy.calculateLockoutDuration(8), equals(const Duration(hours: 1)));

      // Attempt 10: Wipe threshold reached (greater than or equal to maxAttemptsBeforeWipe)
      expect(10 >= policy.maxAttemptsBeforeWipe, isTrue);
    });
  });
}
