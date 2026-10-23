import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// RFC 6238 Time-Based One-Time Password (TOTP) and Base32 engine.
///
/// 100% offline, zero cloud, zero telemetry, zero external native dependencies.
class TotpService {
  TotpService._();

  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Decodes an RFC 4648 Base32 string into raw secret bytes.
  static Uint8List? decodeBase32(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    if (cleaned.isEmpty) return null;

    final bytes = <int>[];
    int buffer = 0;
    int bitsLeft = 0;

    for (int i = 0; i < cleaned.length; i++) {
      final val = _base32Alphabet.indexOf(cleaned[i]);
      if (val < 0) continue;
      buffer = (buffer << 5) | val;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        bytes.add((buffer >> bitsLeft) & 0xFF);
      }
    }
    return Uint8List.fromList(bytes);
  }

  /// Generates a standard 6-digit TOTP code for the given Base32 secret.
  static String generateCode(
    String base32Secret, {
    int intervalSeconds = 30,
    int digits = 6,
    DateTime? time,
  }) {
    final keyBytes = decodeBase32(base32Secret);
    if (keyBytes == null || keyBytes.isEmpty) return '------';

    final nowSeconds = (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final counter = nowSeconds ~/ intervalSeconds;

    // 8-byte big-endian counter
    final msg = Uint8List(8);
    var temp = counter;
    for (int i = 7; i >= 0; i--) {
      msg[i] = temp & 0xFF;
      temp >>= 8;
    }

    final hmac = Hmac(sha1, keyBytes);
    final hash = hmac.convert(msg).bytes;

    final offset = hash[hash.length - 1] & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);

    final otp = binary % pow(10, digits).toInt();
    return otp.toString().padLeft(digits, '0');
  }

  /// Calculates remaining seconds in the current 30-second epoch.
  static int getRemainingSeconds({int intervalSeconds = 30, DateTime? time}) {
    final nowSeconds = (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final remaining = intervalSeconds - (nowSeconds % intervalSeconds);
    return remaining == 0 ? intervalSeconds : remaining;
  }

  /// Calculates the normalized progress (0.0 -> 1.0) of the current epoch.
  static double getRemainingProgress({int intervalSeconds = 30, DateTime? time}) {
    final nowSeconds = (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final elapsed = nowSeconds % intervalSeconds;
    return (intervalSeconds - elapsed) / intervalSeconds;
  }
}
