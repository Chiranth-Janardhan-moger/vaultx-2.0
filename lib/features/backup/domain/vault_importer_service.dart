import 'dart:convert';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';

enum ImportSource {
  chromeCsv,
  bitwardenCsv,
  bitwardenJson,
  onePasswordCsv,
  genericCsv,
}

extension ImportSourceExtension on ImportSource {
  String get label {
    switch (this) {
      case ImportSource.chromeCsv:
        return 'Google Chrome CSV';
      case ImportSource.bitwardenCsv:
        return 'Bitwarden CSV';
      case ImportSource.bitwardenJson:
        return 'Bitwarden JSON';
      case ImportSource.onePasswordCsv:
        return '1Password CSV';
      case ImportSource.genericCsv:
        return 'Generic CSV';
    }
  }
}

class ImportResult {
  final ImportSource source;
  final List<VaultPasswordEntry> entries;
  final int totalCount;
  final String? errorMessage;

  const ImportResult({
    required this.source,
    required this.entries,
    required this.totalCount,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
  bool get isEmpty => entries.isEmpty;
}

/// Service to parse credential exports from Google Chrome, Bitwarden, and 1Password.
class VaultImporterService {
  /// Parses raw CSV or JSON file contents into a list of [VaultPasswordEntry].
  static ImportResult parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const ImportResult(
        source: ImportSource.genericCsv,
        entries: [],
        totalCount: 0,
        errorMessage: 'The selected file is empty.',
      );
    }

    if (trimmed.startsWith('{')) {
      return _parseJson(trimmed);
    }

    return _parseCsv(trimmed);
  }

  static ImportResult _parseJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const ImportResult(
          source: ImportSource.bitwardenJson,
          entries: [],
          totalCount: 0,
          errorMessage: 'Invalid JSON format.',
        );
      }

      // Check for Bitwarden JSON structure
      final items = decoded['items'];
      if (items is List) {
        final entries = <VaultPasswordEntry>[];
        final now = DateTime.now();

        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          if (item is! Map<String, dynamic>) continue;

          final name = item['name'] as String? ?? 'Untitled';
          final notes = item['notes'] as String? ?? '';
          final login = item['login'] as Map<String, dynamic>?;

          String username = '';
          String password = '';
          String totp = '';
          String url = '';

          if (login != null) {
            username = login['username'] as String? ?? '';
            password = login['password'] as String? ?? '';
            totp = login['totp'] as String? ?? '';

            final uris = login['uris'];
            if (uris is List && uris.isNotEmpty) {
              final firstUri = uris.first;
              if (firstUri is Map && firstUri['uri'] is String) {
                url = firstUri['uri'] as String;
              }
            }
          }

          final isFavorite = item['favorite'] as bool? ?? false;

          if (name.isNotEmpty || username.isNotEmpty || password.isNotEmpty || notes.isNotEmpty) {
            entries.add(
              VaultPasswordEntry(
                id: 'imported-bw-${now.microsecondsSinceEpoch}-$i',
                title: name,
                username: username,
                email: username.contains('@') ? username : '',
                password: password,
                websiteUrl: url,
                notes: notes,
                totpSecret: totp,
                category: 'Others',
                createdAt: now,
                updatedAt: now,
                isFavorite: isFavorite,
              ),
            );
          }
        }

        return ImportResult(
          source: ImportSource.bitwardenJson,
          entries: entries,
          totalCount: entries.length,
        );
      }

      return const ImportResult(
        source: ImportSource.bitwardenJson,
        entries: [],
        totalCount: 0,
        errorMessage: 'JSON structure does not match supported password manager export format.',
      );
    } catch (e) {
      return ImportResult(
        source: ImportSource.bitwardenJson,
        entries: const [],
        totalCount: 0,
        errorMessage: 'Failed to parse JSON: $e',
      );
    }
  }

  static ImportResult _parseCsv(String csvString) {
    try {
      final rows = _splitCsvRows(csvString);
      if (rows.isEmpty) {
        return const ImportResult(
          source: ImportSource.genericCsv,
          entries: [],
          totalCount: 0,
          errorMessage: 'No data rows found in CSV.',
        );
      }

      final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
      final dataRows = rows.skip(1).toList();

      // Detect source by header signatures
      final isBitwarden = header.contains('login_username') || header.contains('login_password');
      final isChrome = header.contains('name') && header.contains('url') && header.contains('password');
      final isOnePassword = header.contains('title') && (header.contains('website') || header.contains('url'));

      final source = isBitwarden
          ? ImportSource.bitwardenCsv
          : isChrome
              ? ImportSource.chromeCsv
              : isOnePassword
                  ? ImportSource.onePasswordCsv
                  : ImportSource.genericCsv;

      // Find column indices
      int titleIdx = _findColumn(header, ['name', 'title']);
      int usernameIdx = _findColumn(header, ['login_username', 'username', 'login']);
      int passwordIdx = _findColumn(header, ['login_password', 'password', 'pass']);
      int urlIdx = _findColumn(header, ['login_uri', 'url', 'website', 'uri']);
      int notesIdx = _findColumn(header, ['notes', 'note', 'comment']);
      int totpIdx = _findColumn(header, ['login_totp', 'totp', '2fa']);
      int folderIdx = _findColumn(header, ['folder', 'category']);

      final entries = <VaultPasswordEntry>[];
      final now = DateTime.now();

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

        String getCol(int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

        final title = getCol(titleIdx);
        final username = getCol(usernameIdx);
        final password = getCol(passwordIdx);
        final url = getCol(urlIdx);
        final notes = getCol(notesIdx);
        final totp = getCol(totpIdx);
        final folder = getCol(folderIdx);

        // Discard row if it has neither title, username, nor password
        if (title.isEmpty && username.isEmpty && password.isEmpty && notes.isEmpty) {
          continue;
        }

        final effectiveTitle = title.isNotEmpty
            ? title
            : (url.isNotEmpty ? Uri.tryParse(url)?.host ?? url : 'Imported Item');

        entries.add(
          VaultPasswordEntry(
            id: 'imported-csv-${now.microsecondsSinceEpoch}-$i',
            title: effectiveTitle,
            username: username,
            email: username.contains('@') ? username : '',
            password: password,
            websiteUrl: url,
            notes: notes,
            totpSecret: totp,
            category: (folder.isNotEmpty && folder.trim().toLowerCase() != 'all') ? folder.trim() : 'Others',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      return ImportResult(
        source: source,
        entries: entries,
        totalCount: entries.length,
      );
    } catch (e) {
      return ImportResult(
        source: ImportSource.genericCsv,
        entries: const [],
        totalCount: 0,
        errorMessage: 'Failed to parse CSV file: $e',
      );
    }
  }

  static int _findColumn(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = header.indexOf(candidate);
      if (idx != -1) return idx;
    }
    return -1;
  }

  /// Robust CSV row tokenizer that handles quoted cells, escaped quotes (""), and internal commas.
  static List<List<String>> _splitCsvRows(String input) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var insideQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        if (insideQuotes && i + 1 < input.length && input[i + 1] == '"') {
          // Escaped quote: "" -> "
          currentCell.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        currentRow.add(currentCell.toString());
        currentCell.clear();
      } else if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentCell.toString());
        currentCell.clear();
        if (currentRow.any((c) => c.isNotEmpty)) {
          rows.add(List.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentCell.write(char);
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }
}
