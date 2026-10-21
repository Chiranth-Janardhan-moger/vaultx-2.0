import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:local_auth/local_auth.dart';
import 'package:vaultx/core/crypto/kdf_service.dart';
import 'package:vaultx/core/crypto/vault_cipher.dart';
import 'package:vaultx/core/crypto/lockout_policy.dart';
import 'package:vaultx/core/crypto/biometric_auth_service.dart';
import 'package:vaultx/core/storage/secure_key_storage.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  group('Argon2id KDF Service Tests', () {
    late KdfService kdfService;

    setUp(() {
      kdfService = const KdfService(defaultParams: KdfParameters.testProfile);
    });

    test('KDF determinism: identical password and salt produce identical 32-byte key', () async {
      const password = 'CorrectHorseBatteryStaple!2026';
      final salt = List<int>.generate(16, (i) => i * 7 % 256);

      final key1 = await kdfService.deriveMasterKey(
        masterPassword: password,
        salt: salt,
      );
      final key2 = await kdfService.deriveMasterKey(
        masterPassword: password,
        salt: salt,
      );

      expect(key1.length, equals(32));
      expect(key2.length, equals(32));
      expect(key1, equals(key2));
    });

    test('Salt uniqueness: different salts produce completely different keys', () async {
      const password = 'StandardMasterPassword99#';
      final saltA = List<int>.generate(16, (i) => i);
      final saltB = List<int>.generate(16, (i) => i + 1);

      final keyA = await kdfService.deriveMasterKey(
        masterPassword: password,
        salt: saltA,
      );
      final keyB = await kdfService.deriveMasterKey(
        masterPassword: password,
        salt: saltB,
      );

      expect(keyA, isNot(equals(keyB)));
    });

    test('Password sensitivity: slight variation in password produces different key', () async {
      final salt = List<int>.generate(16, (i) => 42);

      final keyA = await kdfService.deriveMasterKey(
        masterPassword: 'Password123!',
        salt: salt,
      );
      final keyB = await kdfService.deriveMasterKey(
        masterPassword: 'Password123?',
        salt: salt,
      );

      expect(keyA, isNot(equals(keyB)));
    });

    test('Salt generator generates unique 16-byte cryptographically secure salts', () {
      final salt1 = kdfService.generateSalt();
      final salt2 = kdfService.generateSalt();

      expect(salt1.length, equals(16));
      expect(salt2.length, equals(16));
      expect(salt1, isNot(equals(salt2)));
    });

    test('Validation rejects empty password or short salts', () async {
      final validSalt = List<int>.generate(16, (i) => i);

      expect(
        () => kdfService.deriveMasterKey(masterPassword: '', salt: validSalt),
        throwsArgumentError,
      );

      expect(
        () => kdfService.deriveMasterKey(masterPassword: 'valid', salt: [1, 2, 3]),
        throwsArgumentError,
      );
    });
  });

  group('VaultCipher AES-256-GCM Tests', () {
    late VaultCipher cipher;
    late List<int> masterKey;

    setUp(() {
      cipher = VaultCipher();
      masterKey = List<int>.generate(32, (i) => (i * 13) % 256);
    });

    test('Round-trip encryption and decryption preserves exact plaintext', () async {
      const secretPlaintext = '{"service":"GitHub","username":"dev_ops","secret":"ghp_SecretTokenXYZ987"}';
      const entryId = 'vault_entry_001';

      final encrypted = await cipher.encryptString(
        plaintext: secretPlaintext,
        masterKey: masterKey,
        entryId: entryId,
      );

      expect(encrypted.nonce.length, equals(12));
      expect(encrypted.mac.length, equals(16));
      expect(encrypted.ciphertext.isNotEmpty, isTrue);

      final decrypted = await cipher.decryptToString(
        record: encrypted,
        masterKey: masterKey,
        entryId: entryId,
      );

      expect(decrypted, equals(secretPlaintext));
    });

    test('Nonce freshness assertion: 1,000 nonces generated without any collision', () async {
      final seenNonces = <String>{};
      const iterations = 1000;

      for (var i = 0; i < iterations; i++) {
        final record = await cipher.encryptString(
          plaintext: 'secret_$i',
          masterKey: masterKey,
          entryId: 'item_$i',
        );
        final nonceHex = base64Encode(record.nonce);
        expect(seenNonces.contains(nonceHex), isFalse, reason: 'Nonce collision detected at iteration $i');
        seenNonces.add(nonceHex);
      }

      expect(seenNonces.length, equals(iterations));
    });

    test('GCM Tamper Detection: altered ciphertext throws TamperedCiphertextException', () async {
      const plaintext = 'BankingPIN_7890';
      const entryId = 'card_chase_visa';

      final record = await cipher.encryptString(
        plaintext: plaintext,
        masterKey: masterKey,
        entryId: entryId,
      );

      // Flip a bit in the ciphertext
      final tamperedBytes = List<int>.from(record.ciphertext);
      tamperedBytes[0] ^= 0x01;

      final tamperedRecord = EncryptedRecord(
        nonce: record.nonce,
        ciphertext: tamperedBytes,
        mac: record.mac,
      );

      expect(
        () => cipher.decryptToString(
          record: tamperedRecord,
          masterKey: masterKey,
          entryId: entryId,
        ),
        throwsA(isA<TamperedCiphertextException>()),
      );
    });

    test('GCM Tamper Detection: altered authentication tag throws TamperedCiphertextException', () async {
      const plaintext = 'ConfidentialNote';
      const entryId = 'note_001';

      final record = await cipher.encryptString(
        plaintext: plaintext,
        masterKey: masterKey,
        entryId: entryId,
      );

      // Flip a bit in the MAC
      final tamperedMac = List<int>.from(record.mac);
      tamperedMac[tamperedMac.length - 1] ^= 0xFF;

      final tamperedRecord = EncryptedRecord(
        nonce: record.nonce,
        ciphertext: record.ciphertext,
        mac: tamperedMac,
      );

      expect(
        () => cipher.decryptToString(
          record: tamperedRecord,
          masterKey: masterKey,
          entryId: entryId,
        ),
        throwsA(isA<TamperedCiphertextException>()),
      );
    });

    test('AAD validation: attempting decryption under different entry ID throws TamperedCiphertextException', () async {
      const plaintext = 'SecretValue';
      final record = await cipher.encryptString(
        plaintext: plaintext,
        masterKey: masterKey,
        entryId: 'entry_alpha',
      );

      // Swapping target entry ID should fail AAD check
      expect(
        () => cipher.decryptToString(
          record: record,
          masterKey: masterKey,
          entryId: 'entry_beta',
        ),
        throwsA(isA<TamperedCiphertextException>()),
      );
    });

    test('EncryptedRecord JSON serialization round-trip', () {
      final original = EncryptedRecord(
        nonce: List<int>.generate(12, (i) => i),
        ciphertext: List<int>.generate(32, (i) => i * 2),
        mac: List<int>.generate(16, (i) => i * 3),
      );

      final jsonStr = original.toJsonString();
      final restored = EncryptedRecord.fromJsonString(jsonStr);

      expect(restored.nonce, equals(original.nonce));
      expect(restored.ciphertext, equals(original.ciphertext));
      expect(restored.mac, equals(original.mac));
    });
  });

  group('Lockout & Wipe Policy Tests', () {
    late MockFlutterSecureStorage mockStorage;
    late Map<String, String> inMemoryStore;
    late bool wipeTriggered;
    late AuthLockoutPolicy policy;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      inMemoryStore = {};
      wipeTriggered = false;

      when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        return inMemoryStore[key];
      });

      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        final value = inv.namedArguments[#value] as String;
        inMemoryStore[key] = value;
      });

      when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        inMemoryStore.remove(key);
      });

      policy = AuthLockoutPolicy(
        storage: mockStorage,
        maxAttemptsBeforeWipe: 5, // Set to 5 for test
        attemptsBeforeDelay: 3,
        onWipeVault: () async {
          wipeTriggered = true;
        },
      );
    });

    test('Initial status is clean with zero failed attempts', () async {
      final status = await policy.getStatus();
      expect(status.failedAttempts, equals(0));
      expect(status.isLockedOut, isFalse);
      expect(status.isWiped, isFalse);
      expect(status.remainingAttempts, equals(5));
    });

    test('Attempts below delay threshold do not trigger lockout delay', () async {
      final status1 = await policy.recordFailedAttempt();
      expect(status1.failedAttempts, equals(1));
      expect(status1.isLockedOut, isFalse);

      final status2 = await policy.recordFailedAttempt();
      expect(status2.failedAttempts, equals(2));
      expect(status2.isLockedOut, isFalse);
    });

    test('3rd failed attempt triggers progressive delay lockout', () async {
      await policy.recordFailedAttempt(); // 1
      await policy.recordFailedAttempt(); // 2
      final status3 = await policy.recordFailedAttempt(); // 3

      expect(status3.failedAttempts, equals(3));
      expect(status3.isLockedOut, isTrue);
      expect(status3.remainingLockout.inSeconds, greaterThan(0));
    });

    test('Reaching max attempts triggers vault wipe callback', () async {
      expect(wipeTriggered, isFalse);

      for (var i = 1; i <= 4; i++) {
        await policy.recordFailedAttempt();
        expect(wipeTriggered, isFalse);
      }

      // 5th attempt = maxAttemptsBeforeWipe
      final finalStatus = await policy.recordFailedAttempt();
      expect(finalStatus.failedAttempts, equals(5));
      expect(finalStatus.isWiped, isTrue);
      expect(wipeTriggered, isTrue);
    });

    test('Successful authentication resets failure counter and lockout', () async {
      await policy.recordFailedAttempt();
      await policy.recordFailedAttempt();

      var status = await policy.getStatus();
      expect(status.failedAttempts, equals(2));

      await policy.recordSuccessfulAuth();

      status = await policy.getStatus();
      expect(status.failedAttempts, equals(0));
      expect(status.isLockedOut, isFalse);
    });
  });

  group('SecureKeyStorage Tests', () {
    late MockFlutterSecureStorage mockStorage;
    late Map<String, String> inMemoryStore;
    late SecureKeyStorage secureStorage;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      inMemoryStore = {};

      when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        return inMemoryStore[key];
      });

      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        final value = inv.namedArguments[#value] as String;
        inMemoryStore[key] = value;
      });

      when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        inMemoryStore.remove(key);
      });

      when(() => mockStorage.containsKey(key: any(named: 'key'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        return inMemoryStore.containsKey(key);
      });

      secureStorage = SecureKeyStorage(storage: mockStorage);
    });

    test('Stores and retrieves 32-byte master key', () async {
      final key = List<int>.generate(32, (i) => i);
      expect(await secureStorage.hasMasterKey(), isFalse);

      await secureStorage.storeMasterKey(key);
      expect(await secureStorage.hasMasterKey(), isTrue);

      final retrieved = await secureStorage.getMasterKey();
      expect(retrieved, equals(key));
    });

    test('Rejects invalid key size', () async {
      final invalidKey = [1, 2, 3];
      expect(() => secureStorage.storeMasterKey(invalidKey), throwsArgumentError);
    });

    test('Stores and retrieves installation salt', () async {
      final salt = List<int>.generate(16, (i) => i * 2);
      await secureStorage.storeInstallSalt(salt);

      final retrieved = await secureStorage.getInstallSalt();
      expect(retrieved, equals(salt));
    });

    test('Wipe removes master key and salt', () async {
      await secureStorage.storeMasterKey(List<int>.generate(32, (i) => i));
      await secureStorage.storeInstallSalt(List<int>.generate(16, (i) => i));

      await secureStorage.wipeAllKeys();

      expect(await secureStorage.getMasterKey(), isNull);
      expect(await secureStorage.getInstallSalt(), isNull);
      expect(await secureStorage.hasMasterKey(), isFalse);
    });
  });

  group('BiometricAuthService Tests', () {
    late MockLocalAuthentication mockAuth;
    late BiometricAuthService service;

    setUp(() {
      mockAuth = MockLocalAuthentication();
      when(() => mockAuth.getAvailableBiometrics()).thenAnswer((_) async => <BiometricType>[BiometricType.fingerprint]);
      service = BiometricAuthService(auth: mockAuth);
    });

    test('Returns true when biometric authentication succeeds', () async {
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      )).thenAnswer((_) async => true);

      final result = await service.authenticate();
      expect(result, isTrue);
    });

    test('Returns false when biometrics are not supported on device', () async {
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => false);
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => false);

      final result = await service.authenticate();
      expect(result, isFalse);
    });
  });
}
