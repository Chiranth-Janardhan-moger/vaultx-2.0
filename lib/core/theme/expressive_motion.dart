import 'package:flutter/material.dart';

/// Material 3 Expressive motion tokens, spring physics, and curve definitions.
///
/// Material 3 Expressive introduces emphasized, spring-based motion curves,
/// dynamic tactile responses, and expressive easing for buttons, sliders, and icons.
class ExpressiveMotion {
  ExpressiveMotion._();

  // --- Easing Curves (Material 3 Expressive) ---
  /// Emphasized curve for standard expressive transitions (entrance + exit combined)
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Emphasized decelerate curve for incoming elements (elements entering the screen or expanding)
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Emphasized accelerate curve for outgoing elements (elements exiting the screen or collapsing)
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Expressive bouncy spring curve for tactile press releases and micro-interactions
  static const Curve springBouncy = _ExpressiveSpringCurve();

  /// Snappy bounce curve with gentle overshoot
  static const Curve snappy = Cubic(0.18, 0.89, 0.32, 1.25);

  // --- Durations ---
  static const Duration durationShort1 = Duration(milliseconds: 50);
  static const Duration durationShort2 = Duration(milliseconds: 100);
  static const Duration durationShort3 = Duration(milliseconds: 150);
  static const Duration durationShort4 = Duration(milliseconds: 200);

  static const Duration durationMedium1 = Duration(milliseconds: 250);
  static const Duration durationMedium2 = Duration(milliseconds: 300);
  static const Duration durationMedium3 = Duration(milliseconds: 350);
  static const Duration durationMedium4 = Duration(milliseconds: 400);

  static const Duration durationLong1 = Duration(milliseconds: 450);
  static const Duration durationLong2 = Duration(milliseconds: 500);
  static const Duration durationLong3 = Duration(milliseconds: 550);
  static const Duration durationLong4 = Duration(milliseconds: 600);

  // --- Expressive Spring Physics Specifications ---
  /// Lively spring description for buttons and icon releases
  static const SpringDescription livelySpring = SpringDescription(
    mass: 1.0,
    stiffness: 260.0,
    damping: 18.0,
  );

  /// Snappy spring description for slider thumbs and toggles
  static const SpringDescription snappySpring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 24.0,
  );

  /// Gentle spring description for floating tooltips and balloon indicators
  static const SpringDescription gentleSpring = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 16.0,
  );

  // --- Press Scaling Factors ---
  static const double buttonPressScale = 0.96;
  static const double iconButtonPressScale = 0.88;
  static const double sliderThumbPressScale = 1.24;
}

/// Custom bouncy spring curve for Material 3 Expressive micro-interactions
class _ExpressiveSpringCurve extends Curve {
  const _ExpressiveSpringCurve();

  @override
  double transformInternal(double t) {
    // Damped harmonic oscillation curve for realistic physical spring feel
    // t ranges from 0.0 to 1.0
    if (t == 0.0 || t == 1.0) return t;
    return (1.0 - (1.0 - t)) *
            (1.0 - 0.15 * (1.0 - t)) +
        0.08 *
            (1.0 - t) *
            (1.0 - t) *
            (1.0 - t) *
            (1.0 - t) *
            (1.0 - t) *
            (1.0 - t) *
            (1.0 - t) +
        (1.0 - (1.0 - t)) * (1.0 - (1.0 - t)) * (1.0 - (1.0 - t));
  }
}
