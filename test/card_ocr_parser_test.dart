import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/features/wallet/presentation/card_scanner/card_ocr_parser.dart';

void main() {
  group('CardOcrParser Tests', () {
    test('Correctly extracts Visa card number, expiry, and holder name', () {
      final lines = [
        'CHASE SAPPHIRE',
        '4532 8920 1840 9214',
        'GOOD THRU 08/29',
        'ALEX MORGAN',
      ];
      final fullText = lines.join('\n');

      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: fullText,
      );

      expect(result.cardNumber, equals('4532892018409214'));
      expect(result.expiry, equals('08/29'));
      expect(result.cardholderName, equals('ALEX MORGAN'));
      expect(result.network, equals('Visa'));
      expect(result.hasDetails, isTrue);
    });

    test('Correctly detects Mastercard network and expiration date', () {
      final lines = [
        'CITI BANK',
        '5412 7512 3412 3456',
        'VALID 12/28',
        'SARAH CONNOR',
      ];
      final fullText = lines.join('\n');

      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: fullText,
      );

      expect(result.cardNumber, equals('5412751234123456'));
      expect(result.expiry, equals('12/28'));
      expect(result.cardholderName, equals('SARAH CONNOR'));
      expect(result.network, equals('Mastercard'));
    });

    test('Ignores blacklisted words like BANK, DEBIT, VALID THRU as cardholder name', () {
      final lines = [
        'PREMIER BANK DEBIT',
        '4111 1111 1111 1111',
        'EXP 05/27',
        'JOHN SMITH',
      ];
      final fullText = lines.join('\n');

      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: fullText,
      );

      expect(result.cardNumber, equals('4111111111111111'));
      expect(result.expiry, equals('05/27'));
      expect(result.cardholderName, equals('JOHN SMITH'));
    });

    // ── Mixed-case OCR output ──────────────────────────────────────────────
    test('Handles mixed-case OCR output for cardholder name', () {
      final lines = [
        'HDFC Bank',
        '4539 1488 0343 6467',
        'Valid Thru 09/28',
        'Priya Sharma', // mixed-case — OCR reads it this way
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('PRIYA SHARMA'));
    });

    // ── Single-word name ──────────────────────────────────────────────────
    test('Extracts single-word cardholder name', () {
      final lines = [
        'VISA CLASSIC',
        '4532 1488 0343 6467',
        '07/26',
        'MADONNA',
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('MADONNA'));
    });

    // ── Hyphenated surname ────────────────────────────────────────────────
    test('Handles hyphenated cardholder surname', () {
      final lines = [
        '4532 1488 0343 6467',
        '11/29',
        'EMMA WATSON-SMITH',
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('EMMA WATSON-SMITH'));
    });

    // ── Apostrophe in name ────────────────────────────────────────────────
    test("Handles name with apostrophe like O'BRIEN", () {
      final lines = [
        '5500 0000 0000 0004',
        '03/27',
        "RYAN O'BRIEN",
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals("RYAN O'BRIEN"));
    });

    // ── Three-word compound name ──────────────────────────────────────────
    test('Extracts three-word compound cardholder name', () {
      final lines = [
        'AMERICAN EXPRESS',
        '3714 496353 98431',
        'MEMBER SINCE 01/20',
        'VALID THRU 09/28',
        'MARY JANE WATSON',
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('MARY JANE WATSON'));
    });

    // ── Positional scoring picks bottom-most valid candidate ──────────────
    test('Picks best candidate by position when multiple alpha-only lines exist', () {
      final lines = [
        'WORLD ELITE',         // index 0 — blacklisted words
        '4111 1111 1111 1111', // index 1 — digits
        '08/29',               // index 2 — expiry
        'JAMES BOND',          // index 3 — correct name (highest score)
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('JAMES BOND'));
    });

    // ── All-lowercase OCR line ────────────────────────────────────────────
    test('Handles fully lowercase OCR output', () {
      final lines = [
        'sbi bank',
        '4111 1111 1111 1111',
        '06/28',
        'rahul gupta', // all lowercase
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('RAHUL GUPTA'));
    });

    // ── Expiry written as MM-YY (dashes) ─────────────────────────────────
    test('Skips dash-separated expiry line correctly', () {
      final lines = [
        '4532 8920 1840 9214',
        '08-29', // dash format — must not be treated as name
        'NINA SIMONE',
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('NINA SIMONE'));
    });

    // ── Returns empty when no valid name found ────────────────────────────
    test('Returns empty string when no cardholder name can be found', () {
      final lines = [
        '4532 8920 1840 9214',
        'VALID THRU 08/29',
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, isEmpty);
    });

    // ── No false-positive on bank/product names ───────────────────────────
    test('Does not pick bank or product name as cardholder', () {
      final lines = [
        'HDFC PLATINUM', // blacklisted words
        '4532 8920 1840 9214',
        '08/29',
        'AMRIT SINGH',
      ];
      final result = CardOcrParser.parseLines(
        lines: lines,
        fullText: lines.join('\n'),
      );

      expect(result.cardholderName, equals('AMRIT SINGH'));
    });
  });
}
