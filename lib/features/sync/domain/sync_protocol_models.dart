import 'dart:convert';
import 'package:vaultx/core/crypto/vault_cipher.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';

/// Rendezvous payload encoded into the pairing QR code and manual connection string.
///
/// Contains strictly connection metadata for LAN discovery and relay routing.
/// Conforms to §6.2.2: Pure rendezvous — zero cryptographic keys or credentials.
class SyncRendezvousPayload {
  final String sessionId;
  final String deviceName;
  final List<String> ipAddresses;
  final int port;
  final String? relayUrl;
  final int version;
  final DateTime expiresAt;

  SyncRendezvousPayload({
    required this.sessionId,
    required this.deviceName,
    required this.ipAddresses,
    required this.port,
    this.relayUrl,
    this.version = 1,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? DateTime.now().add(const Duration(seconds: 60));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'sid': sessionId,
        'dev': deviceName,
        'ips': ipAddresses,
        'prt': port,
        if (relayUrl != null) 'rly': relayUrl,
        'ver': version,
        'exp': expiresAt.millisecondsSinceEpoch,
      };

  String toJsonString() => jsonEncode(toJson());

  factory SyncRendezvousPayload.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SyncRendezvousPayload(
      sessionId: map['sid'] as String,
      deviceName: map['dev'] as String? ?? 'VaultX Peer',
      ipAddresses: (map['ips'] as List<dynamic>).cast<String>(),
      port: map['prt'] as int,
      relayUrl: map['rly'] as String?,
      version: map['ver'] as int? ?? 1,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['exp'] as int),
    );
  }
}

/// Encrypted wire transport frame crossing the WebSocket / Relay boundary.
///
/// Every message over the wire is authenticated ciphertext using AES-256-GCM.
class SyncTransportFrame {
  final String messageType;
  final String nonceBase64;
  final String ciphertextBase64;
  final String tagBase64;
  final int timestamp;

  const SyncTransportFrame({
    required this.messageType,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.tagBase64,
    required this.timestamp,
  });

  EncryptedRecord toEncryptedRecord() {
    return EncryptedRecord(
      nonce: base64Decode(nonceBase64),
      ciphertext: base64Decode(ciphertextBase64),
      mac: base64Decode(tagBase64),
    );
  }

  factory SyncTransportFrame.fromEncryptedRecord({
    required String messageType,
    required EncryptedRecord record,
  }) {
    return SyncTransportFrame(
      messageType: messageType,
      nonceBase64: base64Encode(record.nonce),
      ciphertextBase64: base64Encode(record.ciphertext),
      tagBase64: base64Encode(record.mac),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        't': messageType,
        'n': nonceBase64,
        'c': ciphertextBase64,
        'm': tagBase64,
        'ts': timestamp,
      };

  String toJsonString() => jsonEncode(toJson());

  factory SyncTransportFrame.fromJsonString(String str) {
    final map = jsonDecode(str) as Map<String, dynamic>;
    return SyncTransportFrame(
      messageType: map['t'] as String,
      nonceBase64: map['n'] as String,
      ciphertextBase64: map['c'] as String,
      tagBase64: map['m'] as String,
      timestamp: map['ts'] as int,
    );
  }
}

/// Initial unencrypted ephemeral public key exchange frame.
///
/// Only exchanged at initial socket connection before ECDH shared secret is derived.
class HandshakeInitMessage {
  final String sessionId;
  final String publicKeyBase64;
  final String deviceName;

  const HandshakeInitMessage({
    required this.sessionId,
    required this.publicKeyBase64,
    required this.deviceName,
  });

  Map<String, dynamic> toJson() => {
        'sid': sessionId,
        'pub': publicKeyBase64,
        'dev': deviceName,
      };

  String toJsonString() => jsonEncode(toJson());

  factory HandshakeInitMessage.fromJsonString(String str) {
    final map = jsonDecode(str) as Map<String, dynamic>;
    return HandshakeInitMessage(
      sessionId: map['sid'] as String,
      publicKeyBase64: map['pub'] as String,
      deviceName: map['dev'] as String? ?? 'Peer Device',
    );
  }
}

/// Container for vault data to be synced across the encrypted channel.
class SyncVaultBundle {
  final List<VaultPasswordEntry> passwords;
  final List<WalletCardEntry> cards;
  final int exportedAtTimestamp;
  final String sourceDeviceId;

  const SyncVaultBundle({
    required this.passwords,
    required this.cards,
    required this.exportedAtTimestamp,
    required this.sourceDeviceId,
  });

  Map<String, dynamic> toJson() => {
        'passwords': passwords.map((p) => p.toMap()).toList(),
        'cards': cards.map((c) => c.toMap()).toList(),
        'ts': exportedAtTimestamp,
        'src': sourceDeviceId,
      };

  String toJsonString() => jsonEncode(toJson());

  factory SyncVaultBundle.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final pwList = (map['passwords'] as List<dynamic>? ?? [])
        .map((e) => VaultPasswordEntry.fromMap(e as Map<String, dynamic>))
        .toList();
    final cdList = (map['cards'] as List<dynamic>? ?? [])
        .map((e) => WalletCardEntry.fromMap(e as Map<String, dynamic>))
        .toList();

    return SyncVaultBundle(
      passwords: pwList,
      cards: cdList,
      exportedAtTimestamp: map['ts'] as int? ?? 0,
      sourceDeviceId: map['src'] as String? ?? 'unknown',
    );
  }
}
