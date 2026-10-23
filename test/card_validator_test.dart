import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/features/wallet/domain/card_validator.dart';

void main() {
  group('CardValidator Tests', () {
    test('Correctly detects Visa network and passes Luhn check', () {
      const cardNumber = '4111 1111 1111 1111';
      expect(CardValidator.detectNetwork(cardNumber), equals('Visa'));
      expect(CardValidator.passesLuhn(cardNumber), isTrue);
    });

    test('Correctly detects Mastercard network and passes Luhn check', () {
      const cardNumber = '5500 0000 0000 0004';
      expect(CardValidator.detectNetwork(cardNumber), equals('Mastercard'));
      expect(CardValidator.passesLuhn(cardNumber), isTrue);
    });

    test('Correctly detects American Express network and formats with 4-6-5 grouping', () {
      const amexNumber = '378282246310005';
      expect(CardValidator.detectNetwork(amexNumber), equals('Amex'));
      expect(CardValidator.passesLuhn(amexNumber), isTrue);
      expect(CardValidator.formatCardNumber(amexNumber), equals('3782 822463 10005'));
    });

    test('Correctly detects RuPay network', () {
      const rupayNumber = '6521501234567890';
      expect(CardValidator.detectNetwork(rupayNumber), equals('RuPay'));
    });

    test('Correctly detects Discover network', () {
      const discoverNumber = '6011111111111117';
      expect(CardValidator.detectNetwork(discoverNumber), equals('Discover'));
      expect(CardValidator.passesLuhn(discoverNumber), isTrue);
    });

    test('Rejects invalid card numbers with incorrect Luhn checksum', () {
      const invalidCard = '4111 1111 1111 1112'; // Altered last digit
      expect(CardValidator.passesLuhn(invalidCard), isFalse);
    });

    test('Correctly formats card number with spaces', () {
      expect(CardValidator.formatCardNumber('4111111111111111'), equals('4111 1111 1111 1111'));
      expect(CardValidator.formatCardNumber('4111 1111 1111 1111'), equals('4111 1111 1111 1111'));
    });

    test('Formats and validates expiry date MM/YY', () {
      expect(CardValidator.formatExpiry('0829'), equals('08/29'));
      expect(CardValidator.formatExpiry('08/29'), equals('08/29'));
      expect(CardValidator.isValidExpiry('12/35'), isTrue);
      expect(CardValidator.isValidExpiry('13/29'), isFalse); // Invalid month
      expect(CardValidator.isValidExpiry('01/19'), isFalse); // Expired year
    });
  });
}
