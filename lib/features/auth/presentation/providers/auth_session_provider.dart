import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/core/crypto/kdf_service.dart';
import 'package:vaultx/core/crypto/biometric_auth_service.dart';
import 'package:vaultx/core/crypto/lockout_policy.dart';
import 'package:vaultx/core/storage/secure_key_storage.dart';

import 'package:vaultx/core/storage/app_settings_storage.dart';
import 'package:vaultx/core/storage/vault_storage_service.dart';

class AuthSessionState {
  final bool isInitialized;
  final bool isAuthenticated;
  final bool hasMasterKey;
  final bool isBiometricsAvailable;
  final bool isBiometricsEnabled;
  final String? errorMessage;
  final List<int>? activeMasterKey;

  const AuthSessionState({
    this.isInitialized = false,
    this.isAuthenticated = false,
    this.hasMasterKey = false,
    this.isBiometricsAvailable = false,
    this.isBiometricsEnabled = true,
    this.errorMessage,
    this.activeMasterKey,
  });

  AuthSessionState copyWith({
    bool? isInitialized,
    bool? isAuthenticated,
    bool? hasMasterKey,
    bool? isBiometricsAvailable,
    bool? isBiometricsEnabled,
    String? errorMessage,
    bool clearError = false,
    List<int>? activeMasterKey,
    bool clearKey = false,
  }) {
    return AuthSessionState(
      isInitialized: isInitialized ?? this.isInitialized,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasMasterKey: hasMasterKey ?? this.hasMasterKey,
      isBiometricsAvailable: isBiometricsAvailable ?? this.isBiometricsAvailable,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeMasterKey: clearKey ? null : (activeMasterKey ?? this.activeMasterKey),
    );
  }
}

class AuthSessionNotifier extends StateNotifier<AuthSessionState> {
  final SecureKeyStorage _secureStorage;
  final KdfService _kdfService;
  final BiometricAuthService _biometricAuth;
  final AuthLockoutPolicy _lockoutPolicy;
  final VaultStorageService _vaultStorage;
  final AppSettingsStorage _settingsStorage;

  AuthSessionNotifier({
    SecureKeyStorage? secureStorage,
    KdfService? kdfService,
    BiometricAuthService? biometricAuth,
    AuthLockoutPolicy? lockoutPolicy,
    VaultStorageService? vaultStorage,
    AppSettingsStorage? settingsStorage,
  })  : _secureStorage = secureStorage ?? SecureKeyStorage(),
        _kdfService = kdfService ?? const KdfService(),
        _biometricAuth = biometricAuth ?? BiometricAuthService(),
        _lockoutPolicy = lockoutPolicy ?? AuthLockoutPolicy(),
        _vaultStorage = vaultStorage ?? VaultStorageService(),
        _settingsStorage = settingsStorage ?? AppSettingsStorage(),
        super(const AuthSessionState()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    // Run both async platform checks concurrently to minimise startup latency.
    final hasKey = _secureStorage.hasMasterKey();
    final canBio = _biometricAuth.isBiometricAvailable();
    state = state.copyWith(
      isInitialized: true,
      hasMasterKey: await hasKey,
      isBiometricsAvailable: await canBio,
    );

    // On Xiaomi MIUI / Android 14, BiometricManager can transiently return
    // BIOMETRIC_ERROR_HW_UNAVAILABLE for ~500 ms after a cold start even when
    // fingerprints are enrolled. Retry once after a short delay so the biometric
    // toggle is never permanently greyed on a device where biometrics do work.
    if (!state.isBiometricsAvailable) {
      Future<void>.delayed(const Duration(milliseconds: 700), () async {
        if (!mounted) return;
        final retry = await _biometricAuth.isBiometricAvailable();
        if (mounted && retry) {
          state = state.copyWith(isBiometricsAvailable: true);
        }
      });
    }
  }

  Future<bool> setupMasterPassword(String password) async {
    if (password.length < 8) {
      state = state.copyWith(errorMessage: 'Password must be at least 8 characters.');
      return false;
    }
    try {
      final salt = _kdfService.generateSalt();
      final masterKey = await _kdfService.deriveMasterKey(
        masterPassword: password,
        salt: salt,
      );
      await _secureStorage.storeInstallSalt(salt);
      await _secureStorage.storeMasterKey(masterKey);
      await _lockoutPolicy.recordSuccessfulAuth();

      state = state.copyWith(
        isAuthenticated: true,
        hasMasterKey: true,
        activeMasterKey: masterKey,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to initialize vault: $e');
      return false;
    }
  }

  Future<bool> unlockWithMasterPassword(String password) async {
    final status = await _lockoutPolicy.getStatus();
    if (status.isLockedOut) {
      state = state.copyWith(
        errorMessage: 'Vault locked. Please wait ${status.remainingLockout.inSeconds} seconds.',
      );
      return false;
    }

    try {
      final salt = await _secureStorage.getInstallSalt();
      final storedKey = await _secureStorage.getMasterKey();

      if (salt == null || storedKey == null) {
        // Vault not yet initialized; treat as setup
        return await setupMasterPassword(password);
      }

      final derivedKey = await _kdfService.deriveMasterKey(
        masterPassword: password,
        salt: salt,
      );

      // Constant-time comparison
      bool matches = true;
      if (derivedKey.length != storedKey.length) {
        matches = false;
      } else {
        int diff = 0;
        for (int i = 0; i < derivedKey.length; i++) {
          diff |= derivedKey[i] ^ storedKey[i];
        }
        matches = (diff == 0);
      }

      if (matches) {
        await _lockoutPolicy.recordSuccessfulAuth();
        state = state.copyWith(
          isAuthenticated: true,
          activeMasterKey: derivedKey,
          clearError: true,
        );
        return true;
      } else {
        final newStatus = await _lockoutPolicy.recordFailedAttempt();
        state = state.copyWith(
          errorMessage: 'Incorrect master password. ${newStatus.remainingAttempts} attempts remaining.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Unlock failed: $e');
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    final isAvailable = state.isBiometricsAvailable || (await _biometricAuth.isBiometricAvailable());
    if (!isAvailable) {
      state = state.copyWith(errorMessage: 'Biometrics not available or enrolled on this device.');
      return false;
    }
    try {
      final success = await _biometricAuth.authenticate(
        localizedReason: 'Scan your fingerprint to unlock VaultX',
      );
      if (success) {
        final storedKey = await _secureStorage.getMasterKey();
        if (storedKey != null) {
          await _lockoutPolicy.recordSuccessfulAuth();
          state = state.copyWith(
            isAuthenticated: true,
            activeMasterKey: storedKey,
            clearError: true,
          );
          return true;
        } else {
          state = state.copyWith(
            errorMessage: 'Vault not initialized. Please enter master password.',
          );
          return false;
        }
      }
      state = state.copyWith(
        errorMessage: 'Biometric authentication cancelled or not recognized.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Biometric authentication failed: $e');
      return false;
    }
  }

  void lockVault() {
    state = state.copyWith(
      isAuthenticated: false,
      clearKey: true,
      clearError: true,
    );
  }

  Future<void> wipeAllData() async {
    await _secureStorage.wipeAllKeys();
    await _lockoutPolicy.reset();
    await _vaultStorage.wipeAll();
    await _settingsStorage.wipe();
    state = const AuthSessionState(
      isInitialized: true,
      isAuthenticated: false,
      hasMasterKey: false,
    );
  }

  /// Changes the master password.
  ///
  /// Verifies [currentPassword] against the stored derived key first,
  /// then derives a brand-new key from [newPassword] with a fresh salt and
  /// overwrites secure storage atomically.
  ///
  /// Returns a [ChangeMasterPasswordResult] indicating success or failure reason.
  Future<ChangeMasterPasswordResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      return ChangeMasterPasswordResult.weakNewPassword;
    }

    try {
      final salt = await _secureStorage.getInstallSalt();
      final storedKey = await _secureStorage.getMasterKey();

      if (salt == null || storedKey == null) {
        return ChangeMasterPasswordResult.vaultNotInitialized;
      }

      // Verify current password via constant-time comparison
      final currentDerived = await _kdfService.deriveMasterKey(
        masterPassword: currentPassword,
        salt: salt,
      );

      bool matches = currentDerived.length == storedKey.length;
      int diff = 0;
      for (int i = 0; i < currentDerived.length; i++) {
        diff |= currentDerived[i] ^ storedKey[i];
      }
      matches = matches && (diff == 0);

      if (!matches) {
        return ChangeMasterPasswordResult.incorrectCurrentPassword;
      }

      // Derive new key with fresh salt
      final newSalt = _kdfService.generateSalt();
      final newKey = await _kdfService.deriveMasterKey(
        masterPassword: newPassword,
        salt: newSalt,
      );

      // Re-encrypt all vault passwords and cards with the new master key
      await _vaultStorage.reEncryptAll(
        oldMasterKey: currentDerived,
        newMasterKey: newKey,
      );

      // Persist the new credentials, rolling back re-encryption on disk if storage fails
      try {
        await _secureStorage.storeInstallSalt(newSalt);
        await _secureStorage.storeMasterKey(newKey);
      } catch (err) {
        await _vaultStorage.reEncryptAll(
          oldMasterKey: newKey,
          newMasterKey: currentDerived,
        );
        rethrow;
      }

      // Update active session key so the user stays logged in
      state = state.copyWith(activeMasterKey: newKey, clearError: true);

      return ChangeMasterPasswordResult.success;
    } catch (e) {
      return ChangeMasterPasswordResult.unexpectedError;
    }
  }
}

/// Result codes for the change-master-password operation.
enum ChangeMasterPasswordResult {
  success,
  incorrectCurrentPassword,
  weakNewPassword,
  vaultNotInitialized,
  unexpectedError,
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSessionState>((ref) {
  final vaultStorage = ref.watch(vaultStorageServiceProvider);
  return AuthSessionNotifier(vaultStorage: vaultStorage);
});
