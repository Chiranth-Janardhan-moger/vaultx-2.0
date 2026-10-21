import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vaultx/core/storage/app_secure_storage.dart';
import 'package:vaultx/core/storage/app_settings_storage.dart';

/// Available auto-lock durations after the app is closed or backgrounded.
enum AutoLockDuration {
  sec30('30sec', '30 Seconds', Duration(seconds: 30)),
  min1('1min', '1 Minute', Duration(minutes: 1)),
  min2('2min', '2 Minutes', Duration(minutes: 2)),
  min3('3min', '3 Minutes', Duration(minutes: 3)),
  min4('4min', '4 Minutes', Duration(minutes: 4)),
  min5('5min', '5 Minutes', Duration(minutes: 5));

  final String id;
  final String label;
  final Duration duration;

  const AutoLockDuration(this.id, this.label, this.duration);

  static AutoLockDuration fromId(String? id) {
    return AutoLockDuration.values.firstWhere(
      (element) => element.id == id,
      orElse: () => AutoLockDuration.min5,
    );
  }
}

/// Manages and persists the user's preferred auto-lock timeout.
class AutoLockNotifier extends StateNotifier<AutoLockDuration> {
  final AppSettingsStorage _settingsStorage;
  final FlutterSecureStorage _secureStorage;
  static const _storageKey = 'vaultx_auto_lock_duration';

  AutoLockNotifier({
    AppSettingsStorage? settingsStorage,
    FlutterSecureStorage? secureStorage,
  })  : _settingsStorage = settingsStorage ?? AppSettingsStorage(),
        _secureStorage = secureStorage ?? AppSecureStorage.instance,
        super(AutoLockDuration.min5) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      // 1. Try file-backed settings storage
      final settings = await _settingsStorage.readSettings();
      final savedId = settings[_storageKey] as String?;
      if (savedId != null) {
        state = AutoLockDuration.fromId(savedId);
        return;
      }

      // 2. Fallback to secure storage
      final secureSavedId = await _secureStorage.read(key: _storageKey);
      if (secureSavedId != null) {
        state = AutoLockDuration.fromId(secureSavedId);
      }
    } catch (_) {
      // Fallback gracefully to default
    }
  }

  Future<void> setDuration(AutoLockDuration duration) async {
    state = duration;
    // Persist immediately in both file-backed storage and secure storage
    await _settingsStorage.writeSetting(_storageKey, duration.id);
    try {
      await _secureStorage.write(key: _storageKey, value: duration.id);
    } catch (_) {}
  }
}

final autoLockProvider =
    StateNotifierProvider<AutoLockNotifier, AutoLockDuration>((ref) {
  return AutoLockNotifier();
});
