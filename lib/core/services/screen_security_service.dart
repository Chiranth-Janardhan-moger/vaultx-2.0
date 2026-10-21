import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/core/storage/app_settings_storage.dart';

/// Service and notifier to manage Screen Privacy (FLAG_SECURE on Android).
///
/// Prevents screenshots and cloaks the app preview in the system multitasking
/// switcher to protect sensitive cryptographic secrets and passwords.
class ScreenSecurityNotifier extends StateNotifier<bool> {
  static const MethodChannel _channel = MethodChannel('com.vaultx.vaultx/screen_security');
  static const String _storageKey = 'vaultx_screen_privacy';
  final AppSettingsStorage _settingsStorage;

  ScreenSecurityNotifier({AppSettingsStorage? settingsStorage})
      : _settingsStorage = settingsStorage ?? AppSettingsStorage(),
        super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final settings = await _settingsStorage.readSettings();
      final enabled = settings[_storageKey] as bool? ?? true;
      state = enabled;
      await _applyNative(enabled);
    } catch (e) {
      debugPrint('ScreenSecurityNotifier load error: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _settingsStorage.writeSetting(_storageKey, enabled);
    await _applyNative(enabled);
  }

  Future<void> _applyNative(bool enabled) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<bool>(enabled ? 'enable' : 'disable');
      }
    } catch (e) {
      debugPrint('ScreenSecurityNotifier platform call error: $e');
    }
  }
}

final screenSecurityProvider =
    StateNotifierProvider<ScreenSecurityNotifier, bool>((ref) {
  return ScreenSecurityNotifier();
});
