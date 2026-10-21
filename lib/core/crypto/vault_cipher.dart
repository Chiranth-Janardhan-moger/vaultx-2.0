import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Exception thrown when decryption fails due to ciphertext tampering or invalid authentication tag.
class TamperedCiphertextException implements Exception {
  final String message;
  const TamperedCiphertextException([this.message = 'Ciphertext authentication failed; data may be tampered.']);

  @override
  String toString() => 'TamperedCiphertextException: $message';
}

/// Represents an encrypted data packet with its nonce and GCM authentication tag.
class EncryptedRecord {
  /// 12-byte (96-bit) initialization vector / nonce.
  final List<int> nonce;

  /// The raw encrypted bytes.
  final List<int> ciphertext;

  /// 16-byte (128-bit) GCM authentication tag / MAC.
  final List<int> mac;

  const EncryptedRecord({
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  /// Serializes into a base64-packed JSON payload suitable for database storage.
  String toJsonString() {
    return jsonEncode({
      'n': base64Encode(nonce),
      'c': base64Encode(ciphertext),
      'm': base64Encode(mac),
    });
  }

  /// Deserializes an [EncryptedRecord] from a serialized JSON payload.
  factory EncryptedRecord.fromJsonString(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      return EncryptedRecord(
        nonce: base64Decode(map['n'] as String),
        ciphertext: base64Decode(map['c'] as String),
        mac: base64Decode(map['m'] as String),
      );
    } catch (e) {
      throw FormatException('Invalid encrypted record format: $e');
    }
  }
}

/// High-security authenticated cipher using AES-256-GCM.
///
/// Encrypts and decrypts vault records individually under entry-derived keys with
/// cryptographically fresh 96-bit nonces per write operation.
class VaultCipher {
  final AesGcm _algorithm;
  final Hmac _hkdfHmac;

  VaultCipher()
      : _algorithm = AesGcm.with256bits(),
        _hkdfHmac = Hmac.sha256();

  /// Derives an entry-specific 256-bit encryption key from [masterKey] using HKDF with [entryId] context.
  Future<SecretKey> deriveEntryKey({
    required List<int> masterKey,
    required String entryId,
  }) async {
    if (masterKey.length != 32) {
      throw ArgumentError('Master key must be exactly 32 bytes.');
    }

    final hkdf = Hkdf(
      hmac: _hkdfHmac,
      outputLength: 32,
    );

    final masterSecretKey = SecretKey(masterKey);
    final entryContext = utf8.encode('vaultx_entry_key_$entryId');
    final salt = utf8.encode(entryId);

    final derived = await hkdf.deriveKey(
      secretKey: masterSecretKey,
      nonce: salt,
      info: entryContext,
    );

    return derived;
  }

  /// Encrypts plaintext string [plaintext] for a specific vault entry [entryId].
  ///
  /// Generates a fresh 12-byte CSPRNG nonce for every invocation.
  /// Binds [entryId] as Additional Authenticated Data (AAD) to prevent record swapping.
  Future<EncryptedRecord> encryptString({
    required String plaintext,
    required List<int> masterKey,
    required String entryId,
    List<int>? explicitNonce, // For testing nonce uniqueness or deterministic validation
  }) async {
    final entryKey = await deriveEntryKey(masterKey: masterKey, entryId: entryId);
    final clearBytes = utf8.encode(plaintext);
    final aad = utf8.encode(entryId);

    final nonce = explicitNonce ?? _algorithm.newNonce();
    if (nonce.length != 12) {
      throw ArgumentError('AES-GCM nonce must be exactly 12 bytes (96 bits).');
    }

    final secretBox = await _algorithm.encrypt(
      clearBytes,
      secretKey: entryKey,
      nonce: nonce,
      aad: aad,
    );

    return EncryptedRecord(
      nonce: secretBox.nonce,
      ciphertext: secretBox.cipherText,
      mac: secretBox.mac.bytes,
    );
  }

  /// Decrypts an [EncryptedRecord] for vault entry [entryId].
  ///
  /// Throws [TamperedCiphertextException] if the ciphertext, nonce, MAC, or entryId is altered.
  Future<String> decryptToString({
    required EncryptedRecord record,
    required List<int> masterKey,
    required String entryId,
  }) async {
    final entryKey = await deriveEntryKey(masterKey: masterKey, entryId: entryId);
    final aad = utf8.encode(entryId);

    final secretBox = SecretBox(
      record.ciphertext,
      nonce: record.nonce,
      mac: Mac(record.mac),
    );

    try {
      final decryptedBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: entryKey,
        aad: aad,
      );
      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw TamperedCiphertextException('Decryption verification failed: $e');
    }
  }
}
