import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_secure_storage.dart';

/// Secure hardware-backed storage for the cryptographic master key and installation salt.
///
/// NOTE: The master password is NEVER stored here or anywhere else on disk.
/// Only the derived master key is persisted in the platform secure enclave/keychain.
class SecureKeyStorage {
  static const String _keyMasterKey = 'vaultx_master_key';
  static const String _keyInstallSalt = 'vaultx_install_salt';

  final FlutterSecureStorage _storage;

  SecureKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? AppSecureStorage.instance;

  /// Persists the derived 256-bit [masterKey] into hardware-backed secure storage.
  Future<void> storeMasterKey(List<int> masterKey) async {
    if (masterKey.length != 32) {
      throw ArgumentError('Master key must be exactly 32 bytes (256 bits).');
    }
    final encoded = base64Encode(masterKey);
    await _storage.write(key: _keyMasterKey, value: encoded);
  }

  /// Retrieves the derived 256-bit master key, or `null` if the vault has not been initialized.
  Future<List<int>?> getMasterKey() async {
    final encoded = await _storage.read(key: _keyMasterKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length != 32) {
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` if a master key exists in secure storage.
  Future<bool> hasMasterKey() async {
    return await _storage.containsKey(key: _keyMasterKey);
  }

  /// Stores the per-installation salt.
  Future<void> storeInstallSalt(List<int> salt) async {
    if (salt.length < 16) {
      throw ArgumentError('Salt must be at least 16 bytes.');
    }
    final encoded = base64Encode(salt);
    await _storage.write(key: _keyInstallSalt, value: encoded);
  }

  /// Retrieves the per-installation salt, or `null` if none exists.
  Future<List<int>?> getInstallSalt() async {
    final encoded = await _storage.read(key: _keyInstallSalt);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the existing installation salt, or generates and stores a new one via [generator].
  Future<List<int>> getOrCreateInstallSalt(List<int> Function() generator) async {
    final existing = await getInstallSalt();
    if (existing != null) {
      return existing;
    }
    final newSalt = generator();
    await storeInstallSalt(newSalt);
    return newSalt;
  }

  /// Cryptographically wipes all keys and secrets from secure storage.
  Future<void> wipeAllKeys() async {
    await _storage.delete(key: _keyMasterKey);
    await _storage.delete(key: _keyInstallSalt);
  }
}
