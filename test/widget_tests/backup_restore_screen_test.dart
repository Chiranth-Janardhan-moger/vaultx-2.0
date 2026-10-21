import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/features/backup/presentation/backup_restore_screen.dart';

void main() {
  testWidgets('BackupRestoreScreen renders Export and Restore tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: BackupRestoreScreen(initialTabIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Export Backup'), findsOneWidget);
    expect(find.text('Restore Vault'), findsOneWidget);
    expect(find.text('Encrypted VaultX Backup (.vxb)'), findsOneWidget);
    expect(find.text('Export .vxb Backup'), findsOneWidget);
  });

  testWidgets('BackupRestoreScreen switches to Restore tab and displays file picker prompt', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: BackupRestoreScreen(initialTabIndex: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select .vxb Backup File'), findsOneWidget);
    expect(find.text('Inspect & Decrypt Backup'), findsOneWidget);
  });
}
