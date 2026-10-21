import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// TOTP (Time-based One-Time Password) service conforming to RFC 6238 and RFC 4226.
///
/// Features:
/// - RFC 6238 HMAC-SHA1 6-digit generation.
/// - Base32 decoding with tolerance for padding, dashes, spaces, and lowercase.
/// - Parser for standard `otpauth://totp/...` URIs.
/// - Dynamic remaining-time and progress fraction calculations for UI timers.
class TotpService {
  static const String _base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Decodes a Base32 string into raw bytes.
  static Uint8List decodeBase32(String input) {
    final sanitized = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    if (sanitized.isEmpty) return Uint8List(0);

    var buffer = 0;
    var bitsLeft = 0;
    final output = <int>[];

    for (var i = 0; i < sanitized.length; i++) {
      final val = _base32Chars.indexOf(sanitized[i]);
      if (val < 0) continue;

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xff);
      }
    }

    return Uint8List.fromList(output);
  }

  /// Generates a 6-digit TOTP code for the given [secret] at [time].
  static String generateCode(
    String secret, {
    DateTime? time,
    int period = 30,
    int digits = 6,
  }) {
    final keyBytes = decodeBase32(secret);
    if (keyBytes.isEmpty) return '------';

    final epochSeconds = (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final counter = epochSeconds ~/ period;

    final counterBytes = Uint8List(8);
    var tempCounter = counter;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = tempCounter & 0xff;
      tempCounter >>= 8;
    }

    final hmac = Hmac(sha1, keyBytes);
    final digest = hmac.convert(counterBytes).bytes;

    final offset = digest.last & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    final modulo = pow(10, digits).toInt();
    final otp = binary % modulo;

    return otp.toString().padLeft(digits, '0');
  }

  /// Calculates remaining seconds in the current TOTP 30s window.
  static int getRemainingSeconds({DateTime? time, int period = 30}) {
    final epochSeconds = (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final remainder = epochSeconds % period;
    return period - remainder;
  }

  /// Returns remaining time fraction from 1.0 (fresh) down to 0.0 (expired).
  static double getProgressFraction({DateTime? time, int period = 30}) {
    return getRemainingSeconds(time: time, period: period) / period;
  }

  /// Formats a 6-digit code with a middle space for readability (e.g. "481 920").
  static String formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    }
    return code;
  }

  /// Parses an `otpauth://totp/...` URI and returns secret, issuer, and account name.
  static TotpUriData? parseUri(String uriString) {
    try {
      final uri = Uri.parse(uriString.trim());
      if (uri.scheme.toLowerCase() != 'otpauth') return null;
      if (uri.host.toLowerCase() != 'totp') return null;

      final secret = uri.queryParameters['secret'] ?? '';
      if (secret.isEmpty) return null;

      var issuer = uri.queryParameters['issuer'] ?? '';
      var account = '';

      final path = Uri.decodeComponent(uri.path.replaceFirst('/', ''));
      if (path.contains(':')) {
        final parts = path.split(':');
        if (issuer.isEmpty) issuer = parts[0].trim();
        account = parts.sublist(1).join(':').trim();
      } else {
        account = path.trim();
      }

      final period = int.tryParse(uri.queryParameters['period'] ?? '') ?? 30;
      final digits = int.tryParse(uri.queryParameters['digits'] ?? '') ?? 6;

      return TotpUriData(
        secret: secret,
        issuer: issuer,
        account: account,
        period: period,
        digits: digits,
      );
    } catch (_) {
      return null;
    }
  }
}

class TotpUriData {
  final String secret;
  final String issuer;
  final String account;
  final int period;
  final int digits;

  const TotpUriData({
    required this.secret,
    required this.issuer,
    required this.account,
    this.period = 30,
    this.digits = 6,
  });
}
