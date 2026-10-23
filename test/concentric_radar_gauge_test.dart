import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';
import 'package:vaultx/features/vault/presentation/widgets/concentric_radar_gauge.dart';

void main() {
  testWidgets('ConcentricRadarGauge renders animated score and interactive metrics', (tester) async {
    int selectedFilter = 0;
    bool quickResolveWeakTriggered = false;

    final entry1 = VaultPasswordEntry(
      id: '1',
      title: 'Google',
      username: 'user1',
      password: '123', // Weak & lacks 2FA
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final report = VaultWatchtowerReport(
      totalCredentials: 1,
      healthScore: 50,
      healthStatus: 'Moderate Risk',
      reusedEntries: const [],
      passwordReuseCount: const {},
      weakEntries: [entry1],
      weakEntropyMap: {'1': 10.0},
      missing2faEntries: [entry1],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConcentricRadarGauge(
              report: report,
              selectedFilterIndex: selectedFilter,
              onFilterSelected: (idx) {
                selectedFilter = idx;
              },
              onQuickResolveWeak: () {
                quickResolveWeakTriggered = true;
              },
            ),
          ),
        ),
      ),
    );

    // Pump animation entrance
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('50'), findsOneWidget);
    expect(find.text('/100'), findsOneWidget);
    expect(find.text('MODERATE RISK'), findsOneWidget);

    expect(find.text('Uniqueness'), findsOneWidget);
    expect(find.text('Entropy'), findsOneWidget);
    expect(find.text('2FA Cover'), findsOneWidget);

    // Check quick resolve chip
    expect(find.text('Auto-Strengthen Weak'), findsOneWidget);
    await tester.tap(find.text('Auto-Strengthen Weak'));
    await tester.pump();

    expect(quickResolveWeakTriggered, isTrue);

    // Tap 'Entropy' legend item
    await tester.tap(find.text('Entropy'));
    await tester.pump();

    expect(selectedFilter, equals(2));
  });
}
