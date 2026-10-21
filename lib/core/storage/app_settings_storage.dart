import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Robust local storage for non-sensitive application settings
/// (auto-lock duration, biometric enable/disable preference, theme mode).
///
/// Persists directly into the application documents directory as JSON.
/// Works reliably across Android, iOS, Windows desktop, macOS, Linux, and Web,
/// bypassing platform keystore timing issues during cold startup.
class AppSettingsStorage {
  static const String _fileName = 'vaultx_settings.json';
  final Directory? overrideDir;

  AppSettingsStorage({this.overrideDir});

  Future<File> _getFile() async {
    final dir = overrideDir ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, dynamic>> readSettings() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return {};
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return {};
      }
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (e) {
      debugPrint('AppSettingsStorage read error: $e');
      return {};
    }
  }

  Future<void> writeSetting(String key, dynamic value) async {
    try {
      final settings = await readSettings();
      settings[key] = value;
      final file = await _getFile();
      await file.writeAsString(jsonEncode(settings), flush: true);
    } catch (e) {
      debugPrint('AppSettingsStorage write error for $key: $e');
    }
  }

  Future<void> wipe() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('AppSettingsStorage wipe error: $e');
    }
  }
}
