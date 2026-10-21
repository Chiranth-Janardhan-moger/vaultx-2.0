import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized configuration for FlutterSecureStorage across all platforms.
///
/// Ensures consistent options (encryptedSharedPreferences on Android,
/// Keychain accessibility on Apple platforms, DPAPI on Windows) so that
/// different components do not access conflicting keystores or crash on Android 12+.
class AppSecureStorage {
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
}
