/// Pure Dart validation and formatting utilities for payment cards.
///
/// 100% offline and air-gapped — zero dependencies on external ML or OCR libraries.
class CardValidator {
  static const Set<String> supportedNetworks = {
    'Visa',
    'Mastercard',
    'Amex',
    'Discover',
    'RuPay',
    'Plexee',
  };

  /// Validates card number against the Luhn algorithm (Mod 10).
  static bool passesLuhn(String number) {
    final clean = number.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 13 || clean.length > 19) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = clean.length - 1; i >= 0; i--) {
      int n = int.tryParse(clean[i]) ?? -1;
      if (n == -1) return false;
      if (alternate) {
        n *= 2;
        if (n > 9) n = (n % 10) + 1;
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10 == 0);
  }

  /// Automatically identifies the card network from Issuer Identification Numbers (IIN/BIN).
  static String detectNetwork(String cardNumber) {
    final clean = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return 'Visa';

    // Visa: Starts with 4
    if (clean.startsWith('4')) return 'Visa';

    // Mastercard: 51-55 or 2221-2720
    if (clean.startsWith(RegExp(r'^5[1-5]')) ||
        clean.startsWith(RegExp(r'^2(22[1-9]|2[3-9]|[3-6]|7[0-1]|720)'))) {
      return 'Mastercard';
    }

    // American Express: 34 or 37
    if (clean.startsWith(RegExp(r'^3[47]'))) return 'Amex';

    // Discover specific prefix 6011 or 644-649
    if (clean.startsWith('6011') || clean.startsWith(RegExp(r'^64[4-9]'))) {
      return 'Discover';
    }

    // RuPay: 60 (except 6011), 6521, 6522, 508, 353, 356
    if (clean.startsWith('60') ||
        clean.startsWith('6521') ||
        clean.startsWith('6522') ||
        clean.startsWith('508')) {
      return 'RuPay';
    }

    // Discover: Remaining 65 range
    if (clean.startsWith(RegExp(r'^65'))) {
      return 'Discover';
    }

    return 'Visa';
  }

  /// Formats raw digits with standard 4-digit spacing (or 4-6-5 for Amex).
  static String formatCardNumber(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';

    final isAmex = clean.startsWith('34') || clean.startsWith('37');
    final buffer = StringBuffer();

    if (isAmex) {
      // 4-6-5 grouping for Amex (max 15 digits)
      for (int i = 0; i < clean.length && i < 15; i++) {
        if (i == 4 || i == 10) buffer.write(' ');
        buffer.write(clean[i]);
      }
    } else {
      // 4-4-4-4 grouping for Visa/Mastercard/RuPay (max 16-19 digits)
      for (int i = 0; i < clean.length && i < 19; i++) {
        if (i > 0 && i % 4 == 0) buffer.write(' ');
        buffer.write(clean[i]);
      }
    }

    return buffer.toString();
  }

  /// Formats expiry input into MM/YY format.
  static String formatExpiry(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';

    if (clean.length <= 2) {
      return clean;
    }
    final mm = clean.substring(0, 2);
    final yy = clean.substring(2, clean.length > 4 ? 4 : clean.length);
    return '$mm/$yy';
  }

  /// Validates MM/YY expiry date format and checks if it is not in the past.
  static bool isValidExpiry(String expiry) {
    final match = RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').firstMatch(expiry.trim());
    if (match == null) return false;

    final month = int.tryParse(match.group(1)!) ?? 0;
    final year = 2000 + (int.tryParse(match.group(2)!) ?? 0);

    final now = DateTime.now();
    final cardDate = DateTime(year, month + 1, 0); // End of the expiry month
    return cardDate.isAfter(now);
  }
}
