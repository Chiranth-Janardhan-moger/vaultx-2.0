import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import '../../vault/domain/vault_password_entry.dart';
import '../../wallet/domain/wallet_card_entry.dart';

/// Exception thrown when a backup file has an invalid format or corrupted structure.
class InvalidBackupFormatException implements Exception {
  final String message;
  const InvalidBackupFormatException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when the user provides an incorrect decryption password for a backup.
class InvalidBackupPasswordException implements Exception {
  final String message;
  const InvalidBackupPasswordException([this.message = 'The backup password you entered is incorrect.']);

  @override
  String toString() => message;
}

/// Result payload containing the decrypted and parsed contents of a VaultX (.vxb) backup.
class VxbBackupPayload {
  final String version;
  final DateTime timestamp;
  final List<VaultPasswordEntry> passwords;
  final List<WalletCardEntry> cards;

  const VxbBackupPayload({
    required this.version,
    required this.timestamp,
    required this.passwords,
    required this.cards,
  });

  int get totalItemCount => passwords.length + cards.length;
}

/// Service providing cryptographic export and restore of VaultX (.vxb) backup files.
///
/// Implements full two-way compatibility with the React Native / Expo VaultX backup format
/// using OpenSSL/CryptoJS AES-256-CBC password derivation (EVP_BytesToKey with MD5).
class VxbBackupService {
  static const String currentVersion = '2.0';
  static const String openSslMagic = 'Salted__';

  final AesCbc _cipher = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);

  /// Generates an encrypted .vxb backup string from passwords and wallet cards.
  Future<String> exportBackup({
    required List<VaultPasswordEntry> passwords,
    required List<WalletCardEntry> cards,
    required String backupPassword,
  }) async {
    if (backupPassword.isEmpty) {
      throw ArgumentError('Backup password cannot be empty.');
    }

    final sanitizedPasswords = passwords.where((p) => !p.isDeleted).map((p) {
      return <String, dynamic>{
        'id': p.id,
        'service': p.title,
        'title': p.title,
        'username': p.username,
        'email': p.email,
        'password': p.password,
        'category': p.category,
        'websiteUrl': p.websiteUrl,
        'notes': p.notes,
        'createdAt': p.createdAt.millisecondsSinceEpoch,
        'updatedAt': p.updatedAt.millisecondsSinceEpoch,
        'modifiedAt': p.updatedAt.millisecondsSinceEpoch,
      };
    }).toList();

    final sanitizedCards = cards.where((c) => !c.isDeleted).map((c) {
      return <String, dynamic>{
        'id': c.id,
        'type': 'credit_card',
        'title': c.title,
        'holderName': c.cardholderName,
        'cardholderName': c.cardholderName,
        'number': c.cardNumber,
        'cardNumber': c.cardNumber,
        'expiry': c.expiry,
        'cvv': c.cvv,
        'network': c.network,
        'cardTheme': c.cardTheme,
        'fields': <Map<String, dynamic>>[
          {'label': 'Expiry', 'value': c.expiry, 'isSensitive': false},
          {'label': 'CVV', 'value': c.cvv, 'isSensitive': true},
        ],
        'createdAt': c.createdAt.millisecondsSinceEpoch,
        'updatedAt': c.updatedAt.millisecondsSinceEpoch,
      };
    }).toList();

    final innerPayload = json.encode({
      'passwords': sanitizedPasswords,
      'cards': sanitizedCards,
    });

    final encryptedPayload = await _encryptCryptoJs(innerPayload, backupPassword);

    final completeBackup = {
      'version': currentVersion,
      'passwords': encryptedPayload,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return json.encode(completeBackup);
  }

  /// Parses and decrypts a .vxb backup file content string using the provided backup password.
  Future<VxbBackupPayload> restoreBackup({
    required String fileContent,
    required String backupPassword,
  }) async {
    if (backupPassword.isEmpty) {
      throw const InvalidBackupPasswordException('Backup password cannot be empty.');
    }

    Map<String, dynamic> backupJson;
    try {
      backupJson = json.decode(fileContent) as Map<String, dynamic>;
    } catch (_) {
      throw const InvalidBackupFormatException('File is not a valid JSON VaultX backup.');
    }

    final version = backupJson['version']?.toString() ?? '1.0';
    final timestampMs = backupJson['timestamp'] is int
        ? backupJson['timestamp'] as int
        : (int.tryParse(backupJson['timestamp']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);

    final encryptedBlob = backupJson['passwords']?.toString();
    if (encryptedBlob == null || encryptedBlob.isEmpty) {
      throw const InvalidBackupFormatException('No encrypted vault payload found in backup file.');
    }

    String decryptedString;
    try {
      decryptedString = await _decryptCryptoJs(encryptedBlob, backupPassword);
    } catch (e) {
      if (e is InvalidBackupPasswordException) rethrow;
      throw const InvalidBackupPasswordException();
    }

    Map<String, dynamic> vaultData;
    try {
      vaultData = json.decode(decryptedString) as Map<String, dynamic>;
    } catch (_) {
      throw const InvalidBackupFormatException('Decrypted vault payload is corrupted.');
    }

    final rawPasswords = vaultData['passwords'] as List<dynamic>? ?? [];
    final rawCards = vaultData['cards'] as List<dynamic>? ?? [];

    final restoredPasswords = <VaultPasswordEntry>[];
    for (final item in rawPasswords) {
      if (item is! Map<String, dynamic>) continue;
      restoredPasswords.add(_mapPasswordItem(item));
    }

    final restoredCards = <WalletCardEntry>[];
    for (final item in rawCards) {
      if (item is! Map<String, dynamic>) continue;
      restoredCards.add(_mapCardItem(item));
    }

    return VxbBackupPayload(
      version: version,
      timestamp: timestamp,
      passwords: restoredPasswords,
      cards: restoredCards,
    );
  }

  VaultPasswordEntry _mapPasswordItem(Map<String, dynamic> item) {
    final title = item['service']?.toString() ?? item['title']?.toString() ?? 'Untitled';
    final username = item['username']?.toString() ?? '';
    final email = item['email']?.toString() ?? '';
    final password = item['password']?.toString() ?? '';
    final category = item['category']?.toString() ?? item['folder']?.toString() ?? 'All';
    final websiteUrl = item['websiteUrl']?.toString() ?? '';
    final notes = item['notes']?.toString() ?? '';

    DateTime createdAt = DateTime.now();
    if (item['createdAt'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(item['createdAt'] as int);
    } else if (item['createdAt'] is String) {
      createdAt = DateTime.tryParse(item['createdAt'] as String) ?? DateTime.now();
    }

    DateTime updatedAt = createdAt;
    final modified = item['modifiedAt'] ?? item['updatedAt'];
    if (modified is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(modified);
    } else if (modified is String) {
      updatedAt = DateTime.tryParse(modified) ?? createdAt;
    }

    final id = item['id']?.toString() ??
        'imported_${title.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_${createdAt.millisecondsSinceEpoch}';

    return VaultPasswordEntry(
      id: id,
      title: title,
      username: username,
      email: email,
      password: password,
      category: category,
      websiteUrl: websiteUrl,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  WalletCardEntry _mapCardItem(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? 'imported_card_${DateTime.now().millisecondsSinceEpoch}';
    final title = item['title']?.toString() ?? 'Payment Card';
    final holderName = item['holderName']?.toString() ?? item['cardholderName']?.toString() ?? '';
    final number = item['number']?.toString() ?? item['cardNumber']?.toString() ?? '';
    final cardTheme = item['cardTheme']?.toString() ?? 'standard';

    String expiry = item['expiry']?.toString() ?? '';
    String cvv = item['cvv']?.toString() ?? '';

    // If fields array is present (D:\Projects\apps\VaultX schema)
    if (item['fields'] is List) {
      for (final field in item['fields'] as List) {
        if (field is Map<String, dynamic>) {
          final label = field['label']?.toString().toLowerCase() ?? '';
          final val = field['value']?.toString() ?? '';
          if (expiry.isEmpty && (label.contains('expiry') || label.contains('valid'))) {
            expiry = val;
          } else if (cvv.isEmpty && (label.contains('cvv') || label.contains('cvc') || label.contains('pin'))) {
            cvv = val;
          }
        }
      }
    }

    String network = item['network']?.toString() ?? '';
    if (network.isEmpty) {
      final clean = number.replaceAll(RegExp(r'\D'), '');
      if (clean.startsWith('4')) {
        network = 'Visa';
      } else if (clean.startsWith(RegExp(r'5[1-5]'))) {
        network = 'Mastercard';
      } else if (clean.startsWith(RegExp(r'3[47]'))) {
        network = 'Amex';
      } else {
        network = 'Plexee';
      }
    }

    DateTime createdAt = DateTime.now();
    if (item['createdAt'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(item['createdAt'] as int);
    } else if (item['createdAt'] is String) {
      createdAt = DateTime.tryParse(item['createdAt'] as String) ?? DateTime.now();
    }

    DateTime updatedAt = createdAt;
    final modified = item['updatedAt'] ?? item['modifiedAt'];
    if (modified is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(modified);
    } else if (modified is String) {
      updatedAt = DateTime.tryParse(modified) ?? createdAt;
    }

    return WalletCardEntry(
      id: id,
      title: title,
      cardholderName: holderName,
      cardNumber: number,
      expiry: expiry,
      cvv: cvv,
      network: network,
      cardTheme: cardTheme,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// CryptoJS / OpenSSL compatible AES-256-CBC encryption.
  Future<String> _encryptCryptoJs(String plaintext, String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(8, (_) => random.nextInt(256));

    final derived = _evpBytesToKey(password, salt);
    final keyBytes = derived.key;
    final ivBytes = derived.iv;

    final secretKey = SecretKey(keyBytes);
    final plainBytes = utf8.encode(plaintext);

    final secretBox = await _cipher.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: ivBytes,
    );

    final magic = utf8.encode(openSslMagic);
    final combined = Uint8List.fromList([...magic, ...salt, ...secretBox.cipherText]);
    return base64.encode(combined);
  }

  /// CryptoJS / OpenSSL compatible AES-256-CBC decryption.
  Future<String> _decryptCryptoJs(String base64Ciphertext, String password) async {
    Uint8List rawBytes;
    try {
      rawBytes = base64.decode(base64Ciphertext.trim());
    } catch (_) {
      throw const InvalidBackupFormatException('Backup ciphertext is not valid Base64.');
    }

    if (rawBytes.length < 16) {
      throw const InvalidBackupFormatException('Corrupted ciphertext payload.');
    }

    final header = utf8.decode(rawBytes.sublist(0, 8), allowMalformed: true);
    if (header != openSslMagic) {
      throw const InvalidBackupFormatException('Invalid backup signature. Expected OpenSSL Salted__ header.');
    }

    final salt = rawBytes.sublist(8, 16);
    final cipherBytes = rawBytes.sublist(16);

    final derived = _evpBytesToKey(password, salt);
    final secretKey = SecretKey(derived.key);

    try {
      final decryptedBytes = await _cipher.decrypt(
        SecretBox(cipherBytes, nonce: derived.iv, mac: Mac.empty),
        secretKey: secretKey,
      );
      return utf8.decode(decryptedBytes);
    } catch (_) {
      throw const InvalidBackupPasswordException();
    }
  }

  /// OpenSSL EVP_BytesToKey with MD5 for 256-bit key and 128-bit IV derivation.
  ({List<int> key, List<int> iv}) _evpBytesToKey(String password, List<int> salt) {
    final passBytes = utf8.encode(password);

    // D_1 = MD5(password + salt)
    final d1 = crypto.md5.convert([...passBytes, ...salt]).bytes;
    // D_2 = MD5(D_1 + password + salt)
    final d2 = crypto.md5.convert([...d1, ...passBytes, ...salt]).bytes;
    // D_3 = MD5(D_2 + password + salt)
    final d3 = crypto.md5.convert([...d2, ...passBytes, ...salt]).bytes;

    final key = <int>[...d1, ...d2]; // 32 bytes (256 bits)
    final iv = <int>[...d3]; // 16 bytes (128 bits)

    return (key: key, iv: iv);
  }
}
