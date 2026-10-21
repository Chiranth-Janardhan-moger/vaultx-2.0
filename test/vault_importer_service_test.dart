import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/features/backup/domain/vault_importer_service.dart';

void main() {
  group('VaultImporterService Tests', () {
    test('Parses Google Chrome CSV export correctly', () {
      const chromeCsv = '''name,url,username,password,note
Google,https://accounts.google.com,alice@gmail.com,Passw0rd123!,personal
GitHub,https://github.com/login,alice_dev,DevKey999,work
''';

      final result = VaultImporterService.parse(chromeCsv);

      expect(result.hasError, isFalse);
      expect(result.source, equals(ImportSource.chromeCsv));
      expect(result.totalCount, equals(2));
      expect(result.entries[0].title, equals('Google'));
      expect(result.entries[0].username, equals('alice@gmail.com'));
      expect(result.entries[0].password, equals('Passw0rd123!'));
      expect(result.entries[0].websiteUrl, equals('https://accounts.google.com'));
      expect(result.entries[0].notes, equals('personal'));

      expect(result.entries[1].title, equals('GitHub'));
      expect(result.entries[1].username, equals('alice_dev'));
    });

    test('Parses Bitwarden CSV export including TOTP and folder', () {
      const bitwardenCsv = '''folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp
Social,1,login,Twitter,my twitter notes,,,https://twitter.com,twit_user,SecretBird1,JBSWY3DPEHPK3PXP
Finance,0,login,Chase Bank,pin 1234,,,https://chase.com,chase_user,ChasePass789,
''';

      final result = VaultImporterService.parse(bitwardenCsv);

      expect(result.hasError, isFalse);
      expect(result.source, equals(ImportSource.bitwardenCsv));
      expect(result.totalCount, equals(2));

      expect(result.entries[0].title, equals('Twitter'));
      expect(result.entries[0].category, equals('Social'));
      expect(result.entries[0].username, equals('twit_user'));
      expect(result.entries[0].password, equals('SecretBird1'));
      expect(result.entries[0].totpSecret, equals('JBSWY3DPEHPK3PXP'));
      expect(result.entries[0].hasTotp, isTrue);

      expect(result.entries[1].title, equals('Chase Bank'));
      expect(result.entries[1].category, equals('Finance'));
      expect(result.entries[1].hasTotp, isFalse);
    });

    test('Parses Bitwarden JSON export structure', () {
      const bitwardenJson = '''{
  "encrypted": false,
  "items": [
    {
      "name": "ProtonMail",
      "notes": "Recovery: word1 word2",
      "login": {
        "uris": [{ "uri": "https://mail.proton.me" }],
        "username": "proton_user@proton.me",
        "password": "ProtonPassword321",
        "totp": "HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ"
      }
    }
  ]
}''';

      final result = VaultImporterService.parse(bitwardenJson);

      expect(result.hasError, isFalse);
      expect(result.source, equals(ImportSource.bitwardenJson));
      expect(result.totalCount, equals(1));
      expect(result.entries[0].title, equals('ProtonMail'));
      expect(result.entries[0].websiteUrl, equals('https://mail.proton.me'));
      expect(result.entries[0].password, equals('ProtonPassword321'));
      expect(result.entries[0].totpSecret, equals('HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ'));
    });

    test('Parses 1Password CSV export with quotes and commas', () {
      const onePasswordCsv = '''Title,Website,Username,Password,Notes
"AWS, Cloud Console",https://aws.amazon.com,root,AWSRootPass123,"multi-line
note with ""quotes"""
''';

      final result = VaultImporterService.parse(onePasswordCsv);

      expect(result.hasError, isFalse);
      expect(result.source, equals(ImportSource.onePasswordCsv));
      expect(result.totalCount, equals(1));
      expect(result.entries[0].title, equals('AWS, Cloud Console'));
      expect(result.entries[0].username, equals('root'));
      expect(result.entries[0].password, equals('AWSRootPass123'));
      expect(result.entries[0].notes, contains('multi-line'));
    });

    test('Handles empty and invalid inputs gracefully', () {
      final emptyResult = VaultImporterService.parse('');
      expect(emptyResult.isEmpty, isTrue);

      final invalidJson = VaultImporterService.parse('{ invalid json }');
      expect(invalidJson.hasError, isTrue);
    });
  });
}
