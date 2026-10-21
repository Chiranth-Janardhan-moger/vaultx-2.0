import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';

void main() {
  group('HappyFeedback Tests', () {
    test('HappyFeedback.vibrate runs without error', () async {
      await expectLater(HappyFeedback.vibrate(), completes);
    });

    test('HappyFeedback.celebrate runs without error', () async {
      await expectLater(HappyFeedback.celebrate(), completes);
    });

    testWidgets('HappyFeedback.show displays celebratory message and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  HappyFeedback.show(
                    context,
                    title: 'Success!',
                    message: 'Happy vibration triggered!',
                    icon: Icons.check_circle_rounded,
                  );
                },
                child: const Text('Show Feedback'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Feedback'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300)); // Settle banner

      expect(find.text('Success!'), findsOneWidget);
      expect(find.text('Happy vibration triggered!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('HappyFeedback.show works without title as simple toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  HappyFeedback.show(
                    context,
                    message: 'Password copied to clipboard!',
                  );
                },
                child: const Text('Copy'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Password copied to clipboard!'), findsOneWidget);
    });
  });
}
