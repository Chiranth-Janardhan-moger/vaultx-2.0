import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/crypto/vault_cipher.dart';
import 'package:vaultx/features/backup/domain/vxb_backup_service.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';

void main() {
  group('Breaker Chaos & Stress Test Suite', () {
    final cipher = VaultCipher();
    final masterKey = List<int>.generate(32, (i) => i ^ 0xAA);

    test('CHAOS TEST 1: Bit-Flip Attack against AES-256-GCM Record', () async {
      const entryId = 'target-entry-1';
      const plaintext = 'SuperSecretPassword123!';

      final record = await cipher.encryptString(
        plaintext: plaintext,
        masterKey: masterKey,
        entryId: entryId,
      );

      // Verify legitimate decrypt succeeds
      final decrypted = await cipher.decryptToString(
        record: record,
        masterKey: masterKey,
        entryId: entryId,
      );
      expect(decrypted, equals(plaintext));

      // 1. Bit-flip in ciphertext: must throw TamperedCiphertextException
      final corruptedCiphertext = List<int>.from(record.ciphertext);
      corruptedCiphertext[0] ^= 0x01; // flip 1 bit
      final corruptedRecord1 = EncryptedRecord(
        nonce: record.nonce,
        ciphertext: corruptedCiphertext,
        mac: record.mac,
      );

      expect(
        () => cipher.decryptToString(
          record: corruptedRecord1,
          masterKey: masterKey,
          entryId: entryId,
        ),
        throwsA(isA<TamperedCiphertextException>()),
        reason: 'Tampered ciphertext bit must be rejected by GCM tag verification',
      );

      // 2. Bit-flip in MAC authentication tag: must throw
      final corruptedMac = List<int>.from(record.mac);
      corruptedMac[corruptedMac.length - 1] ^= 0x80;
      final corruptedRecord2 = EncryptedRecord(
        nonce: record.nonce,
        ciphertext: record.ciphertext,
        mac: corruptedMac,
      );

      expect(
        () => cipher.decryptToString(
          record: corruptedRecord2,
          masterKey: masterKey,
          entryId: entryId,
        ),
        throwsA(isA<TamperedCiphertextException>()),
        reason: 'Tampered MAC authentication tag must fail verification',
      );

      // 3. Replay attack: Decrypt with mismatched entryId (AAD binding violation)
      expect(
        () => cipher.decryptToString(
          record: record,
          masterKey: masterKey,
          entryId: 'different-entry-id',
        ),
        throwsA(isA<TamperedCiphertextException>()),
        reason: 'Decryption with altered AAD entryId must fail authentication',
      );
    });

    test('CHAOS TEST 2: Truncated & Corrupted .vxb Backup Payloads', () async {
      final backupService = VxbBackupService();
      final passwords = [
        VaultPasswordEntry(
          id: 'test-1',
          title: 'Google',
          username: 'user@gmail.com',
          password: 'Password123!',
          category: 'Google',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final validBackup = await backupService.exportBackup(
        passwords: passwords,
        cards: [],
        backupPassword: 'StrongBackupPassword2026!',
      );

      // 1. Try restore with incorrect password -> InvalidBackupPasswordException
      expect(
        () => backupService.restoreBackup(
          fileContent: validBackup,
          backupPassword: 'WrongPassword!',
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );

      // 2. Truncate backup payload by 50% -> InvalidBackupFormatException
      final truncatedString = validBackup.substring(0, validBackup.length ~/ 2);
      expect(
        () => backupService.restoreBackup(
          fileContent: truncatedString,
          backupPassword: 'StrongBackupPassword2026!',
        ),
        throwsA(anyOf(
          isA<InvalidBackupFormatException>(),
          isA<InvalidBackupPasswordException>(),
        )),
      );

      // 3. Inject random garbage into encrypted ciphertext field in JSON
      final map = jsonDecode(validBackup) as Map<String, dynamic>;
      map['passwords'] = 'U2FsdGVkX1${base64Encode(List.generate(100, (i) => Random().nextInt(256)))}';
      final corruptPayload = jsonEncode(map);

      expect(
        () => backupService.restoreBackup(
          fileContent: corruptPayload,
          backupPassword: 'StrongBackupPassword2026!',
        ),
        throwsA(anyOf(
          isA<InvalidBackupFormatException>(),
          isA<InvalidBackupPasswordException>(),
        )),
      );
    });

    test('STRESS TEST 3: Throughput & Scaling Benchmark (50,000 items)', () async {
      const count = 50000;
      final stopwatch = Stopwatch()..start();

      final entries = List.generate(count, (i) {
        return VaultPasswordEntry(
          id: 'perf-entry-$i',
          title: 'Account Service #$i',
          username: 'engineer_$i@enterprise.io',
          email: 'engineer_$i@enterprise.io',
          password: 'ComplexP@ssw0rd!_$i',
          category: i % 2 == 0 ? 'Banking' : 'Work',
          websiteUrl: 'https://service-$i.internal.corp',
          notes: 'Notes for entry $i with extra details and token payload data.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });

      final generationTimeMs = stopwatch.elapsedMilliseconds;
      stopwatch.reset();

      // Benchmark Search & Filter across 1,000 items
      const query = 'enterprise.io';
      final searchResults = entries.where((e) {
        return e.title.contains(query) ||
            e.username.contains(query) ||
            e.email.contains(query);
      }).toList();

      final searchTimeMs = stopwatch.elapsedMilliseconds;
      expect(searchResults.length, equals(count));
      expect(searchTimeMs, lessThan(200), reason: 'In-memory linear search of 1,000 items should complete in <200ms');

      // Benchmark VXB Backup Export
      stopwatch.reset();
      final backupJson = await VxbBackupService().exportBackup(
        passwords: entries,
        cards: [],
        backupPassword: 'BenchmarkPassword2026!',
      );
      final exportTimeMs = stopwatch.elapsedMilliseconds;

      expect(backupJson.length, greaterThan(100000));
      expect(exportTimeMs, lessThan(5000), reason: '1,000 items backup encryption must take < 5.0s');

      // Benchmark VXB Backup Restore
      stopwatch.reset();
      final restoredPayload = await VxbBackupService().restoreBackup(
        fileContent: backupJson,
        backupPassword: 'BenchmarkPassword2026!',
      );
      final restoreTimeMs = stopwatch.elapsedMilliseconds;

      expect(restoredPayload.passwords.length, equals(count));
      expect(restoreTimeMs, lessThan(5000), reason: '1,000 items backup restore must take < 5.0s');

      // ignore: avoid_print
      print('=== BREAKER STRESS TEST METRICS ===');
      // ignore: avoid_print
      print('Items: $count');
      // ignore: avoid_print
      print('Generation Time: ${generationTimeMs}ms');
      // ignore: avoid_print
      print('Linear Search 1,000 entries: ${searchTimeMs}ms');
      // ignore: avoid_print
      print('Backup Export 1,000 entries (Argon2id + AES + JSON): ${exportTimeMs}ms (Size: ${(backupJson.length / 1024).toStringAsFixed(1)} KB)');
      // ignore: avoid_print
      print('Backup Restore 1,000 entries: ${restoreTimeMs}ms');
    });
  });
}
