import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/services/totp_service.dart';

void main() {
  group('TotpService Tests', () {
    // RFC 6238 test secret: "12345678901234567890" ASCII
    // In Base32: GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ
    const rfcSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    test('decodes valid Base32 secret into bytes', () {
      final bytes = TotpService.decodeBase32('JBSWY3DPEHPK3PXP');
      expect(bytes, isNotNull);
      expect(bytes!.length, equals(10));
      // JBSWY3DPEHPK3PXP in ASCII is "Hello!\xde\xad\xbe\xef" -> 72, 101, 108, 108, 111, 33...
      expect(bytes[0], equals(72)); // 'H'
      expect(bytes[1], equals(101)); // 'e'
      expect(bytes[2], equals(108)); // 'l'
      expect(bytes[3], equals(108)); // 'l'
      expect(bytes[4], equals(111)); // 'o'
    });

    test('gracefully handles empty or invalid Base32 secret', () {
      expect(TotpService.decodeBase32(''), isNull);
      expect(TotpService.decodeBase32('   '), isNull);
      expect(TotpService.generateCode(''), equals('------'));
    });

    test('generates expected RFC 6238 TOTP codes at specific unix epochs', () {
      // Unix timestamp 59 (epoch / 30 = 1)
      final time59 = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
      final code59 = TotpService.generateCode(rfcSecret, time: time59);
      expect(code59.length, equals(6));
      expect(int.tryParse(code59), isNotNull);

      // Unix timestamp 1111111109
      final time111 = DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000, isUtc: true);
      final code111 = TotpService.generateCode(rfcSecret, time: time111);
      expect(code111, equals('081804'));

      // Unix timestamp 1234567890
      final time123 = DateTime.fromMillisecondsSinceEpoch(1234567890 * 1000, isUtc: true);
      final code123 = TotpService.generateCode(rfcSecret, time: time123);
      expect(code123, equals('005924'));
    });

    test('calculates remaining seconds accurately within 30s epoch', () {
      final time = DateTime.fromMillisecondsSinceEpoch(20 * 1000, isUtc: true);
      // 20 % 30 = 20; 30 - 20 = 10 seconds remaining
      expect(TotpService.getRemainingSeconds(time: time), equals(10));

      final progress = TotpService.getRemainingProgress(time: time);
      expect(progress, closeTo(10 / 30, 0.001));
    });
  });
}
