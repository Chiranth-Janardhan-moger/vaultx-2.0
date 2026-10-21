import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/crypto/totp_service.dart';

void main() {
  group('TotpService Tests', () {
    // RFC 6238 Test Secret: "12345678901234567890" in Base32:
    // "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    const rfcSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    test('Decodes Base32 strings with various formatting', () {
      final bytes1 = TotpService.decodeBase32('JBSWY3DPEHPK3PXP');
      expect(bytes1.isNotEmpty, isTrue);

      // Lowercase and dashes
      final bytes2 = TotpService.decodeBase32('jbswy-3dpe-hpk3-pxp=');
      expect(bytes2, equals(bytes1));
    });

    test('Generates correct RFC 6238 TOTP codes at specific timestamps', () {
      // Timestamp: 59 seconds -> 287082
      final time59 = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
      final code59 = TotpService.generateCode(rfcSecret, time: time59);
      expect(code59, equals('287082'));

      // Timestamp: 1111111109 seconds -> 081804
      final time1 = DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000, isUtc: true);
      final code1 = TotpService.generateCode(rfcSecret, time: time1);
      expect(code1, equals('081804'));

      // Timestamp: 1111111111 seconds -> 050471
      final time2 = DateTime.fromMillisecondsSinceEpoch(1111111111 * 1000, isUtc: true);
      final code2 = TotpService.generateCode(rfcSecret, time: time2);
      expect(code2, equals('050471'));

      // Timestamp: 2000000000 seconds -> 279037
      final time3 = DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000, isUtc: true);
      final code3 = TotpService.generateCode(rfcSecret, time: time3);
      expect(code3, equals('279037'));
    });

    test('Formats 6-digit codes cleanly', () {
      expect(TotpService.formatCode('287082'), equals('287 082'));
      expect(TotpService.formatCode('050471'), equals('050 471'));
    });

    test('Parses standard otpauth URIs', () {
      const uri = 'otpauth://totp/GitHub:user%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&digits=6&period=30';
      final data = TotpService.parseUri(uri);

      expect(data, isNotNull);
      expect(data!.secret, equals('JBSWY3DPEHPK3PXP'));
      expect(data.issuer, equals('GitHub'));
      expect(data.account, equals('user@example.com'));
      expect(data.period, equals(30));
      expect(data.digits, equals(6));
    });

    test('Returns null for invalid URIs', () {
      expect(TotpService.parseUri('invalid-string'), isNull);
      expect(TotpService.parseUri('https://google.com'), isNull);
      expect(TotpService.parseUri('otpauth://hotp/test?secret=123'), isNull);
    });

    test('Calculates remaining seconds and progress correctly', () {
      // 45 seconds -> remainder = 15 -> remaining = 15
      final time = DateTime.fromMillisecondsSinceEpoch(45 * 1000, isUtc: true);
      expect(TotpService.getRemainingSeconds(time: time), equals(15));
      expect(TotpService.getProgressFraction(time: time), closeTo(0.5, 0.01));
    });
  });
}
