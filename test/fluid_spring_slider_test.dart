import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/widgets/expressive/expressive_swipe_slider.dart';

void main() {
  testWidgets('ExpressiveSwipeSlider renders label and triggers on full swipe', (tester) async {
    bool triggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ExpressiveSwipeSlider(
                label: 'Swipe to Test',
                onTrigger: () {
                  triggered = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Swipe to Test'), findsOneWidget);
    expect(triggered, isFalse);

    // Drag the thumb from left to right
    final thumbFinder = find.byType(GestureDetector);
    await tester.drag(thumbFinder, const Offset(260, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(triggered, isTrue);

    // Let completion delay and spring settle
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('ExpressiveSwipeSlider springs back when drag is insufficient', (tester) async {
    bool triggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ExpressiveSwipeSlider(
                label: 'Swipe to Test',
                onTrigger: () {
                  triggered = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    final thumbFinder = find.byType(GestureDetector);
    // Drag only a small distance (50px out of 240px max)
    await tester.drag(thumbFinder, const Offset(50, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(triggered, isFalse);
  });
}
