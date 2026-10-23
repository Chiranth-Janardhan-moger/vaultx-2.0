import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vaultx/core/storage/app_secure_storage.dart';
import 'package:vaultx/core/storage/app_settings_storage.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';

/// App globals holding the root Navigator & ScaffoldMessenger keys for background-safe overlays & toasts.
class AppGlobals {
  AppGlobals._();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

/// Configurable clipboard auto-wipe duration options.
enum ClipboardTimeout {
  off('off', 'Off', Duration.zero),
  sec30('30s', '30s', Duration(seconds: 30)),
  sec60('60s', '60s', Duration(seconds: 60)),
  sec120('120s', '120s', Duration(seconds: 120));

  final String id;
  final String label;
  final Duration duration;

  const ClipboardTimeout(this.id, this.label, this.duration);

  static ClipboardTimeout fromId(String? id) {
    return ClipboardTimeout.values.firstWhere(
      (element) => element.id == id,
      orElse: () => ClipboardTimeout.sec60,
    );
  }
}

/// StateNotifier that manages and persists clipboard auto-clear preference.
class ClipboardTimeoutNotifier extends StateNotifier<ClipboardTimeout> {
  final AppSettingsStorage _settingsStorage;
  final FlutterSecureStorage _secureStorage;
  static const _storageKey = 'vaultx_clipboard_timeout';

  ClipboardTimeoutNotifier({
    AppSettingsStorage? settingsStorage,
    FlutterSecureStorage? secureStorage,
  })  : _settingsStorage = settingsStorage ?? AppSettingsStorage(),
        _secureStorage = secureStorage ?? AppSecureStorage.instance,
        super(ClipboardTimeout.sec60) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final settings = await _settingsStorage.readSettings();
      final savedId = settings[_storageKey] as String?;
      if (savedId != null) {
        state = ClipboardTimeout.fromId(savedId);
        return;
      }
      final secureSavedId = await _secureStorage.read(key: _storageKey);
      if (secureSavedId != null) {
        state = ClipboardTimeout.fromId(secureSavedId);
      }
    } catch (_) {
      // Fallback gracefully to default sec60
    }
  }

  Future<void> setDuration(ClipboardTimeout timeout) async {
    state = timeout;
    await _settingsStorage.writeSetting(_storageKey, timeout.id);
    try {
      await _secureStorage.write(key: _storageKey, value: timeout.id);
    } catch (_) {}
  }
}

final clipboardTimeoutProvider =
    StateNotifierProvider<ClipboardTimeoutNotifier, ClipboardTimeout>((ref) {
  return ClipboardTimeoutNotifier();
});

/// Background-safe service for copying sensitive secrets to the system clipboard
/// and automatically wiping them after the configured timeout expires.
class ClipboardSecurityService {
  ClipboardSecurityService._();

  static Timer? _clearTimer;
  static String? _activeCopiedSecret;

  /// Copies [text] to the system clipboard, triggers tactile feedback,
  /// informs the user via [HappyFeedback], and schedules a secure background wipe
  /// if clipboard auto-clear is enabled.
  static Future<void> copySecure({
    required BuildContext? context,
    required WidgetRef? ref,
    required String text,
    required String label,
    bool isSensitive = true,
  }) async {
    if (text.isEmpty) return;

    // 1. Copy to system clipboard
    await Clipboard.setData(ClipboardData(text: text));

    // 2. Fetch timeout preference
    final timeout = ref != null
        ? ref.read(clipboardTimeoutProvider)
        : ClipboardTimeout.sec60;

    // 3. Cancel any prior clear timer
    _clearTimer?.cancel();
    _clearTimer = null;

    if (timeout == ClipboardTimeout.off || !isSensitive) {
      _activeCopiedSecret = null;
      if (context != null && context.mounted) {
        HappyFeedback.show(
          context,
          message: '$label copied to clipboard',
          icon: Icons.copy_rounded,
        );
      } else {
        _showToast('$label copied to clipboard', Icons.copy_rounded);
      }
      return;
    }

    // 4. Record the secret and inform the user of auto-wipe
    _activeCopiedSecret = text;
    final notice = '$label copied (clears in ${timeout.label})';

    if (context != null && context.mounted) {
      HappyFeedback.show(
        context,
        message: notice,
        icon: Icons.content_paste_go_rounded,
      );
    } else {
      _showToast(notice, Icons.content_paste_go_rounded);
    }

    // 5. Schedule background wipe
    _clearTimer = Timer(timeout.duration, () async {
      await _executeWipeIfUnchanged(text);
    });
  }

  /// Checks if the clipboard still contains [expectedSecret] before wiping it,
  /// preventing erasure of unrelated content copied by the user in the interim.
  static Future<void> _executeWipeIfUnchanged(String expectedSecret) async {
    try {
      final currentData = await Clipboard.getData(Clipboard.kTextPlain);
      if (currentData?.text == expectedSecret) {
        await Clipboard.setData(const ClipboardData(text: ''));
        _activeCopiedSecret = null;
        _showToast('Clipboard cleared for security', Icons.content_paste_off_rounded);
        try {
          await HapticFeedback.lightImpact();
        } catch (_) {}
      }
    } catch (_) {
      // Ignore platform clipboard access errors
    } finally {
      _clearTimer = null;
    }
  }

  /// Immediately clears the clipboard if it still contains the sensitive secret.
  static Future<void> clearNow() async {
    _clearTimer?.cancel();
    _clearTimer = null;
    if (_activeCopiedSecret != null) {
      await _executeWipeIfUnchanged(_activeCopiedSecret!);
    }
  }

  static void _showToast(String message, IconData icon) {
    final messenger = AppGlobals.scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
