import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/expressive/expressive.dart';

void main() {
  group('Material 3 Expressive Motion Tokens Tests', () {
    test('Expressive motion curves and durations are well-defined', () {
      expect(ExpressiveMotion.emphasized, isA<Cubic>());
      expect(ExpressiveMotion.emphasizedDecelerate, isA<Cubic>());
      expect(ExpressiveMotion.emphasizedAccelerate, isA<Cubic>());
      expect(ExpressiveMotion.springBouncy, isNotNull);
      expect(ExpressiveMotion.snappy, isNotNull);

      expect(ExpressiveMotion.durationShort2.inMilliseconds, equals(100));
      expect(ExpressiveMotion.durationMedium2.inMilliseconds, equals(300));
      expect(ExpressiveMotion.buttonPressScale, equals(0.96));
      expect(ExpressiveMotion.iconButtonPressScale, equals(0.88));
      expect(ExpressiveMotion.sliderThumbPressScale, equals(1.24));
    });
  });

  group('ExpressiveButton Widget Tests', () {
    testWidgets('renders filled button and fires onPressed callback', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: ExpressiveButton.filled(
                label: 'Confirm Vault',
                icon: const Icon(Icons.lock_rounded),
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Confirm Vault'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.text('Confirm Vault'));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('renders tonal, outlined, elevated and text button variants', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                ExpressiveButton.tonal(
                  label: 'Tonal Button',
                  onPressed: () {},
                ),
                ExpressiveButton.outlined(
                  label: 'Outlined Button',
                  onPressed: () {},
                ),
                ExpressiveButton.elevated(
                  label: 'Elevated Button',
                  onPressed: () {},
                ),
                ExpressiveButton.text(
                  label: 'Text Button',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Tonal Button'), findsOneWidget);
      expect(find.text('Outlined Button'), findsOneWidget);
      expect(find.text('Elevated Button'), findsOneWidget);
      expect(find.text('Text Button'), findsOneWidget);
    });

    testWidgets('isLoading state displays progress indicator and ignores taps', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ExpressiveButton(
              isLoading: true,
              label: 'Should Not Show',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Should Not Show'), findsNothing);

      await tester.tap(find.byType(ExpressiveButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(pressed, isFalse);
    });

    testWidgets('ExpressiveSegmentedButton switches selection on item tap', (tester) async {
      String selected = 'Pass';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ExpressiveSegmentedButton<String>(
                  items: const ['Pass', 'Cards', 'Keys'],
                  selectedItem: selected,
                  onSelected: (val) => setState(() => selected = val),
                  itemBuilder: (context, item, isSelected) => Text(item),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Cards'), findsOneWidget);
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();

      expect(selected, equals('Cards'));
    });
  });

  group('ExpressiveIcon & IconButton Widget Tests', () {
    testWidgets('ExpressiveIconButton renders squircle container and fires tap', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: ExpressiveIconButton.filled(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Regenerate',
                enableSpringRotation: true,
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('ExpressiveToggleIcon morphs and invokes onToggle', (tester) async {
      bool isToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ExpressiveToggleIcon(
                  isToggled: isToggled,
                  firstIcon: Icons.visibility_off_outlined,
                  secondIcon: Icons.visibility_outlined,
                  onToggle: (val) => setState(() => isToggled = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(isToggled, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('ExpressiveIconContainer renders with squircle shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExpressiveIconContainer(
              icon: Icon(Icons.shield_rounded),
              size: 48,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
      expect(find.byType(ExpressiveIconContainer), findsOneWidget);
    });
  });

  group('ExpressiveMotionSlider Widget Tests', () {
    testWidgets('ExpressiveVerticalMotionSlider updates on vertical drag', (tester) async {
      int length = 16;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ExpressiveVerticalMotionSlider(
                    value: length,
                    min: 8,
                    max: 32,
                    height: 200,
                    onChanged: (val) => setState(() => length = val),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ExpressiveVerticalMotionSlider), findsOneWidget);

      // Drag vertically up towards 32
      await tester.drag(find.byType(ExpressiveVerticalMotionSlider), const Offset(0, -60));
      await tester.pumpAndSettle();

      expect(length, greaterThan(16));
    });

    testWidgets('ExpressiveSwipeSlider triggers action on complete drag', (tester) async {
      bool triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ExpressiveSwipeSlider(
                  label: 'Swipe to Generate Strong Password',
                  onTrigger: () => triggered = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Swipe to Generate Strong Password'), findsOneWidget);

      // Drag thumb icon across width
      await tester.drag(find.byIcon(Icons.arrow_forward_rounded), const Offset(260, 0));
      await tester.pumpAndSettle();

      expect(triggered, isTrue);
    });
  });
}
