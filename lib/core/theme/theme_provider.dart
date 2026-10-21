import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/core/storage/app_settings_storage.dart';

/// Notifier to manage ThemeMode (Dark, Light, System) across the application,
/// persisted to disk via AppSettingsStorage.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final AppSettingsStorage _settingsStorage;
  static const _key = 'vaultx_theme_mode';

  ThemeModeNotifier({AppSettingsStorage? settingsStorage})
      : _settingsStorage = settingsStorage ?? AppSettingsStorage(),
        super(ThemeMode.dark) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final settings = await _settingsStorage.readSettings();
      final mode = settings[_key] as String?;
      if (mode == 'light') {
        state = ThemeMode.light;
      } else if (mode == 'system') {
        state = ThemeMode.system;
      } else {
        state = ThemeMode.dark;
      }
    } catch (_) {}
  }

  void setMode(ThemeMode mode) {
    state = mode;
    final val = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    _settingsStorage.writeSetting(_key, val);
  }

  void setDark() => setMode(ThemeMode.dark);
  void setLight() => setMode(ThemeMode.light);
  void setSystem() => setMode(ThemeMode.system);

  void toggleTheme() {
    setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
