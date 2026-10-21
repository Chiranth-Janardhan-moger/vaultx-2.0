import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:vaultx/core/crypto/vault_cipher.dart';

/// Cryptographic engine governing secure device-to-device sync pairing.
///
/// Implements:
/// 1. Ephemeral X25519 ECDH key exchange.
/// 2. Key-derived 6-digit numeric verification code (Signal / Bluetooth Numeric Comparison model per §6.2.4).
/// 3. HKDF (SHA-256) session key derivation.
/// 4. Authenticated AES-256-GCM symmetric transport frame encryption.
class SyncCryptoService {
  final X25519 _ecdh = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Random _random = Random.secure();

  /// Generates a single-use ephemeral X25519 keypair for this pairing session.
  Future<SimpleKeyPair> generateEphemeralKeyPair() async {
    return await _ecdh.newKeyPair();
  }

  /// Extracts the 32-byte raw public key bytes from an X25519 [SimpleKeyPair].
  Future<List<int>> extractPublicKeyBytes(SimpleKeyPair keyPair) async {
    final pubKey = await keyPair.extractPublicKey();
    return pubKey.bytes;
  }

  /// Derives an ECDH shared secret between the [localKeyPair] and the [remotePublicKeyBytes].
  Future<SecretKey> deriveSharedSecret({
    required SimpleKeyPair localKeyPair,
    required List<int> remotePublicKeyBytes,
  }) async {
    if (remotePublicKeyBytes.length != 32) {
      throw ArgumentError('Remote X25519 public key must be exactly 32 bytes.');
    }
    final remotePublicKey = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );
    return await _ecdh.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );
  }

  /// Derives the 6-digit numeric verification code from exchanged keys (§6.2.4).
  ///
  /// The verification code is computed as:
  /// SHA-256(min(PubKey_A, PubKey_B) || max(PubKey_A, PubKey_B) || SharedSecret)
  /// Truncated to a 6-digit zero-padded number [000000..999999].
  ///
  /// This ensures that both devices compute the identical code regardless of role
  /// (initiator vs receiver), while an active MITM will cause different codes.
  Future<String> deriveVerificationCode({
    required List<int> localPublicKeyBytes,
    required List<int> remotePublicKeyBytes,
    required SecretKey sharedSecret,
  }) async {
    final sharedSecretBytes = await sharedSecret.extractBytes();

    // Lexicographically sort both public keys to maintain symmetry
    final isLocalSmaller = _compareBytes(localPublicKeyBytes, remotePublicKeyBytes) <= 0;
    final firstKey = isLocalSmaller ? localPublicKeyBytes : remotePublicKeyBytes;
    final secondKey = isLocalSmaller ? remotePublicKeyBytes : localPublicKeyBytes;

    final preimage = <int>[
      ...firstKey,
      ...secondKey,
      ...sharedSecretBytes,
    ];

    final hash = await Sha256().hash(preimage);
    final digest = hash.bytes;

    // Use big-endian unsigned 32-bit integer modulo 1,000,000
    final byteData = ByteData.sublistView(Uint8List.fromList(digest));
    final value = byteData.getUint32(0, Endian.big);
    final code = value % 1000000;

    return code.toString().padLeft(6, '0');
  }

  /// Derives a 256-bit AES-GCM session key using HKDF-SHA256 from the [sharedSecret].
  Future<SecretKey> deriveSessionKey({
    required List<int> localPublicKeyBytes,
    required List<int> remotePublicKeyBytes,
    required SecretKey sharedSecret,
  }) async {
    final isLocalSmaller = _compareBytes(localPublicKeyBytes, remotePublicKeyBytes) <= 0;
    final firstKey = isLocalSmaller ? localPublicKeyBytes : remotePublicKeyBytes;
    final secondKey = isLocalSmaller ? remotePublicKeyBytes : localPublicKeyBytes;

    final saltHash = await Sha256().hash([
      ...firstKey,
      ...secondKey,
    ]);
    final saltDigest = saltHash.bytes;

    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    return await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: saltDigest,
      info: utf8.encode('vaultx-sync-session-v1'),
    );
  }

  /// Encrypts an outgoing JSON message payload using AES-256-GCM.
  ///
  /// Generates a fresh cryptographically secure 12-byte nonce for every message.
  Future<EncryptedRecord> encryptMessage({
    required String cleartextJson,
    required SecretKey sessionKey,
  }) async {
    final cleartextBytes = utf8.encode(cleartextJson);
    final nonce = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      nonce[i] = _random.nextInt(256);
    }

    final secretBox = await _aesGcm.encrypt(
      cleartextBytes,
      secretKey: sessionKey,
      nonce: nonce,
    );

    return EncryptedRecord(
      nonce: secretBox.nonce,
      ciphertext: secretBox.cipherText,
      mac: secretBox.mac.bytes,
    );
  }

  /// Decrypts an incoming [EncryptedRecord] transport frame using AES-256-GCM.
  ///
  /// Throws [TamperedCiphertextException] if authentication tag validation fails.
  Future<String> decryptMessage({
    required EncryptedRecord record,
    required SecretKey sessionKey,
  }) async {
    try {
      final secretBox = SecretBox(
        record.ciphertext,
        nonce: record.nonce,
        mac: Mac(record.mac),
      );

      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: sessionKey,
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw TamperedCiphertextException('Sync message decryption failed: $e');
    }
  }

  int _compareBytes(List<int> a, List<int> b) {
    final len = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      if (a[i] != b[i]) {
        return a[i].compareTo(b[i]);
      }
    }
    return a.length.compareTo(b.length);
  }
}
