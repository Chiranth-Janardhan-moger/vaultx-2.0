import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/widgets/gliding_category_bar.dart';

void main() {
  testWidgets('GlidingCategoryBar renders items with counter badges and handles selection', (tester) async {
    String selected = 'All';

    final items = [
      const GlidingCategoryItem(id: 'All', label: 'All', count: 12),
      const GlidingCategoryItem(id: 'Finance', label: 'Finance', count: 4, dotColor: Colors.green),
      const GlidingCategoryItem(id: 'PINs', label: 'PINs', count: 3, dotColor: Colors.teal),
      const GlidingCategoryItem(id: 'Favorites', label: 'Favorites', count: 2, icon: Icons.star_rounded),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return GlidingCategoryBar(
                items: items,
                selectedId: selected,
                onSelected: (newId) {
                  setState(() {
                    selected = newId;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify labels and micro-counter badges are rendered
    expect(find.text('All'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('PINs'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tap 'Finance'
    await tester.tap(find.text('Finance'));
    await tester.pumpAndSettle();

    expect(selected, equals('Finance'));

    // Tap 'PINs'
    await tester.tap(find.text('PINs'));
    await tester.pumpAndSettle();

    expect(selected, equals('PINs'));
  });
}
