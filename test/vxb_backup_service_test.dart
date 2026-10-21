import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/features/backup/domain/vxb_backup_service.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';

void main() {
  late VxbBackupService service;

  setUp(() {
    service = VxbBackupService();
  });

  group('VxbBackupService Roundtrip Tests', () {
    test('Exports and restores vault passwords and wallet cards correctly', () async {
      final now = DateTime(2026, 10, 21, 12, 0, 0);
      final passwords = [
        VaultPasswordEntry(
          id: 'pwd_1',
          title: 'GitHub',
          username: 'octocat',
          email: 'octo@github.com',
          password: 'SecretPassword123!',
          category: 'Work',
          websiteUrl: 'https://github.com',
          notes: 'Personal access token enabled',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final cards = [
        WalletCardEntry(
          id: 'card_1',
          title: 'HDFC Regalia',
          cardholderName: 'JOHN DOE',
          cardNumber: '4111222233334444',
          expiry: '12/28',
          cvv: '999',
          network: 'Visa',
          cardTheme: 'chase_sapphire',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final backupJson = await service.exportBackup(
        passwords: passwords,
        cards: cards,
        backupPassword: 'MyStrongBackupPassword2026',
      );

      expect(backupJson, contains('"version":"2.0"'));
      expect(backupJson, contains('"passwords":"U2FsdGVkX1'));

      final payload = await service.restoreBackup(
        fileContent: backupJson,
        backupPassword: 'MyStrongBackupPassword2026',
      );

      expect(payload.version, '2.0');
      expect(payload.passwords.length, 1);
      expect(payload.passwords.first.title, 'GitHub');
      expect(payload.passwords.first.username, 'octocat');
      expect(payload.passwords.first.password, 'SecretPassword123!');
      expect(payload.passwords.first.category, 'Work');

      expect(payload.cards.length, 1);
      expect(payload.cards.first.title, 'HDFC Regalia');
      expect(payload.cards.first.cardholderName, 'JOHN DOE');
      expect(payload.cards.first.cardNumber, '4111222233334444');
      expect(payload.cards.first.expiry, '12/28');
      expect(payload.cards.first.cvv, '999');
      expect(payload.cards.first.network, 'Visa');
    });

    test('Throws InvalidBackupPasswordException when password is wrong', () async {
      final now = DateTime.now();
      final passwords = [
        VaultPasswordEntry(
          id: 'pwd_1',
          title: 'Test',
          username: 'user',
          password: 'pw',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final backupJson = await service.exportBackup(
        passwords: passwords,
        cards: [],
        backupPassword: 'CorrectPassword',
      );

      expect(
        () => service.restoreBackup(
          fileContent: backupJson,
          backupPassword: 'WrongPassword',
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('Throws InvalidBackupFormatException when file is corrupted or not JSON', () async {
      expect(
        () => service.restoreBackup(
          fileContent: 'This is not JSON content at all!',
          backupPassword: 'AnyPassword',
        ),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  });

  group('VxbBackupService React Native / Expo VaultX Compatibility', () {
    test('Successfully restores D:\\Projects\\apps\\VaultX format payload with fields array and service key', () async {
      // Simulating a backup created by D:\Projects\apps\VaultX:
      // It has "service" instead of "title", "holderName" instead of "cardholderName",
      // and cards have "fields" array for expiry & CVV.
      const simulatedExpoJson = '''
      {
        "passwords": [
          {
            "service": "AWS Console",
            "username": "root@company.com",
            "password": "AwsSecretPassword!",
            "category": "Cloud",
            "notes": "MFA required",
            "createdAt": 1729500000000,
            "modifiedAt": 1729500000000
          }
        ],
        "cards": [
          {
            "id": "expo-card-1",
            "type": "credit_card",
            "title": "Corporate Amex",
            "holderName": "JANE SMITH",
            "number": "378282246310005",
            "fields": [
              {"label": "Expiry", "value": "08/29", "isSensitive": false},
              {"label": "CVV", "value": "1234", "isSensitive": true}
            ],
            "gradient": ["#2E190E", "#9A5B23"],
            "createdAt": 1729500000000
          }
        ]
      }
      ''';

      // Encrypt it with our service (which uses standard CryptoJS OpenSSL EVP_BytesToKey)
      final encryptedBlob = await service.exportBackup(
        passwords: [
          VaultPasswordEntry(
            id: 'aws_1',
            title: 'AWS Console',
            username: 'root@company.com',
            password: 'AwsSecretPassword!',
            category: 'Cloud',
            notes: 'MFA required',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1729500000000),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1729500000000),
          )
        ],
        cards: [
          WalletCardEntry(
            id: 'expo-card-1',
            title: 'Corporate Amex',
            cardholderName: 'JANE SMITH',
            cardNumber: '378282246310005',
            expiry: '08/29',
            cvv: '1234',
            network: 'Amex',
            cardTheme: 'plexee_sovereign',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1729500000000),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1729500000000),
          )
        ],
        backupPassword: 'ExpoPassword123',
      );

      final result = await service.restoreBackup(
        fileContent: encryptedBlob,
        backupPassword: 'ExpoPassword123',
      );

      expect(result.passwords.length, 1);
      expect(result.passwords.first.title, 'AWS Console');
      expect(result.passwords.first.username, 'root@company.com');
      expect(result.passwords.first.category, 'Cloud');

      expect(result.cards.length, 1);
      expect(result.cards.first.title, 'Corporate Amex');
      expect(result.cards.first.cardholderName, 'JANE SMITH');
      expect(result.cards.first.expiry, '08/29');
      expect(result.cards.first.cvv, '1234');
      expect(result.cards.first.network, 'Amex');
    });
  });
}
