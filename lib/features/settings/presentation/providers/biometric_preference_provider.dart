import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vaultx/core/crypto/biometric_auth_service.dart';
import 'package:vaultx/core/storage/app_secure_storage.dart';
import 'package:vaultx/core/storage/app_settings_storage.dart';

/// Persists the user's preference for biometric unlock.
///
/// Stored in both file-backed AppSettingsStorage and hardware-backed secure storage.
/// When the user enables biometrics, a fingerprint/biometric scan is required to confirm.
class BiometricPreferenceNotifier extends StateNotifier<bool> {
  final AppSettingsStorage _settingsStorage;
  final FlutterSecureStorage _secureStorage;
  final BiometricAuthService _biometricAuth;

  static const _key = 'vaultx_biometric_enabled';

  BiometricPreferenceNotifier({
    AppSettingsStorage? settingsStorage,
    FlutterSecureStorage? secureStorage,
    BiometricAuthService? biometricAuth,
  })  : _settingsStorage = settingsStorage ?? AppSettingsStorage(),
        _secureStorage = secureStorage ?? AppSecureStorage.instance,
        _biometricAuth = biometricAuth ?? BiometricAuthService(),
        super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      // 1. Try file-backed settings first
      final settings = await _settingsStorage.readSettings();
      if (settings.containsKey(_key)) {
        state = settings[_key] == true;
        return;
      }

      // 2. Fallback to secure storage
      final raw = await _secureStorage.read(key: _key);
      if (raw != null) {
        state = raw == 'true';
      }
    } catch (_) {
      state = false;
    }
  }

  /// Prompts for fingerprint and enables biometric unlock if verified.
  Future<bool> enableWithBiometrics({
    String reason = 'Scan your fingerprint to enable biometric unlock',
  }) async {
    try {
      final isAvailable = await _biometricAuth.isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('Cannot enable biometrics: device does not support or has no enrolled biometrics');
        return false;
      }

      final authenticated = await _biometricAuth.authenticate(
        localizedReason: reason,
      );

      if (authenticated) {
        state = true;
        await _settingsStorage.writeSetting(_key, true);
        try {
          await _secureStorage.write(key: _key, value: 'true');
        } catch (_) {}
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error enabling biometrics: $e');
      return false;
    }
  }

  /// Disables biometric unlock.
  Future<void> disable() async {
    state = false;
    await _settingsStorage.writeSetting(_key, false);
    try {
      await _secureStorage.write(key: _key, value: 'false');
    } catch (_) {}
  }

  /// Toggles biometric preference. If [value] is true, prompts fingerprint authentication.
  Future<bool> setEnabled(bool value) async {
    if (value) {
      return await enableWithBiometrics();
    } else {
      await disable();
      return true;
    }
  }
}

final biometricPreferenceProvider =
    StateNotifierProvider<BiometricPreferenceNotifier, bool>((ref) {
  return BiometricPreferenceNotifier();
});
