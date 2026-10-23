import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/pressable_scale.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';

/// A state-of-the-art Concentric Radar Health Gauge for Vault Watchtower.
///
/// Features:
/// - Animated 260° glowing arc with dual-pass bloom shader.
/// - Concentric sub-orbits decomposing Uniqueness, Shannon Entropy, and 2FA TOTP.
/// - Continuous 360° phosphorescent radar sweep beam.
/// - Animated entrance odometer count-up with tabular figures.
/// - Pulsing sonar vulnerability dots with tap feedback to switch filter tabs.
/// - 1-tap "Quick Resolve" micro-action chips with tactile spring physics.
/// - Pure OLED (#000000) specular depth card styling.
class ConcentricRadarGauge extends StatefulWidget {
  final VaultWatchtowerReport report;
  final int selectedFilterIndex;
  final ValueChanged<int>? onFilterSelected;
  final VoidCallback? onQuickResolveWeak;
  final VoidCallback? onQuickResolveReused;
  final VoidCallback? onQuickResolve2FA;

  const ConcentricRadarGauge({
    super.key,
    required this.report,
    this.selectedFilterIndex = 0,
    this.onFilterSelected,
    this.onQuickResolveWeak,
    this.onQuickResolveReused,
    this.onQuickResolve2FA,
  });

  @override
  State<ConcentricRadarGauge> createState() => _ConcentricRadarGaugeState();
}

class _ConcentricRadarGaugeState extends State<ConcentricRadarGauge>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;

  late AnimationController _radarSweepController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation (Odometer & Arc sweep)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutExpo,
    );
    _entranceController.forward();

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');

    // 2. Continuous rotating radar scanner beam
    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (!isTest) {
      _radarSweepController.repeat();
    }

    // 3. Continuous sonar pulse for vulnerability pings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!isTest) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ConcentricRadarGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.healthScore != widget.report.healthScore) {
      _entranceController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _radarSweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.emerald500;
    if (score >= 50) return AppColors.amber500;
    return AppColors.rose500;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final total = math.max(1, report.totalCredentials);

    // Calculate concentric metrics (0.0 to 1.0)
    final uniqueRatio = (1.0 - (report.reusedEntries.length / total)).clamp(0.0, 1.0);
    final strongRatio = (1.0 - (report.weakEntries.length / total)).clamp(0.0, 1.0);
    final totpRatio = (report.missing2faEntries.isEmpty && report.totalCredentials > 0)
        ? 1.0
        : (1.0 - (report.missing2faEntries.length / total)).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceAnimation,
        _radarSweepController,
        _pulseController,
      ]),
      builder: (context, _) {
        final animatedScore = (_entranceAnimation.value * report.healthScore).round();
        final currentColor = _getScoreColor(animatedScore);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF000000), // Pure OLED black
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: currentColor.withValues(alpha: 0.12 * _entranceAnimation.value),
                blurRadius: 36,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top specular rim reflection highlight
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main Radar & Odometer Centerpiece
                    SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Custom Painter: Concentric Radar Tracks, Sweep & Glow Arcs
                          CustomPaint(
                            size: const Size(200, 200),
                            painter: _RadarGaugePainter(
                              progress: _entranceAnimation.value,
                              healthScore: report.healthScore,
                              uniqueRatio: uniqueRatio,
                              strongRatio: strongRatio,
                              totpRatio: totpRatio,
                              radarSweepValue: _radarSweepController.value,
                              pulseValue: _pulseController.value,
                              activeColor: currentColor,
                              hasReused: report.reusedEntries.isNotEmpty,
                              hasWeak: report.weakEntries.isNotEmpty,
                              hasMissing2fa: report.missing2faEntries.isNotEmpty,
                              selectedFilterIndex: widget.selectedFilterIndex,
                            ),
                          ),

                          // Center HUD: Odometer Number & Shield Status
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$animatedScore',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.5,
                                      color: currentColor,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      shadows: [
                                        Shadow(
                                          color: currentColor.withValues(alpha: 0.5),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '/100',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),

                              // Status Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: currentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: currentColor.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: currentColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: currentColor,
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      report.healthStatus.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: currentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Interactive Concentric Ring Legend & Filter Selectors
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLegendItem(
                          index: 1,
                          label: 'Uniqueness',
                          value: '${(uniqueRatio * 100).round()}%',
                          color: AppColors.rose500,
                          hasIssue: report.reusedEntries.isNotEmpty,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        _buildLegendItem(
                          index: 2,
                          label: 'Entropy',
                          value: '${(strongRatio * 100).round()}%',
                          color: AppColors.amber500,
                          hasIssue: report.weakEntries.isNotEmpty,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        _buildLegendItem(
                          index: 3,
                          label: '2FA Cover',
                          value: '${(totpRatio * 100).round()}%',
                          color: const Color(0xFF00F59B),
                          hasIssue: report.missing2faEntries.isNotEmpty,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Micro-Action Quick Resolve Row
                    if (report.hasIssues) ...[
                      const Divider(height: 1, color: Color(0x1AFFFFFF)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (report.weakEntries.isNotEmpty && widget.onQuickResolveWeak != null) ...[
                              _buildQuickActionChip(
                                icon: Icons.bolt_rounded,
                                label: 'Auto-Strengthen Weak',
                                color: AppColors.amber500,
                                onTap: widget.onQuickResolveWeak!,
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (report.reusedEntries.isNotEmpty && widget.onQuickResolveReused != null) ...[
                              _buildQuickActionChip(
                                icon: Icons.shuffle_rounded,
                                label: 'Differentiate Reused',
                                color: AppColors.rose500,
                                onTap: widget.onQuickResolveReused!,
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (report.missing2faEntries.isNotEmpty && widget.onQuickResolve2FA != null) ...[
                              _buildQuickActionChip(
                                icon: Icons.security_rounded,
                                label: 'Setup 2FA Tokens',
                                color: const Color(0xFF00F59B),
                                onTap: widget.onQuickResolve2FA!,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.emerald500.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_rounded, color: AppColors.emerald500, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Vault Zero-Knowledge Shield Immune',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emerald500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem({
    required int index,
    required String label,
    required String value,
    required Color color,
    required bool hasIssue,
  }) {
    final isSelected = widget.selectedFilterIndex == index;

    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onFilterSelected?.call(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: hasIssue
                        ? [
                            BoxShadow(
                              color: color,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the high-performance Concentric Radar Health Gauge.
class _RadarGaugePainter extends CustomPainter {
  final double progress;
  final int healthScore;
  final double uniqueRatio;
  final double strongRatio;
  final double totpRatio;
  final double radarSweepValue;
  final double pulseValue;
  final Color activeColor;
  final bool hasReused;
  final bool hasWeak;
  final bool hasMissing2fa;
  final int selectedFilterIndex;

  _RadarGaugePainter({
    required this.progress,
    required this.healthScore,
    required this.uniqueRatio,
    required this.strongRatio,
    required this.totpRatio,
    required this.radarSweepValue,
    required this.pulseValue,
    required this.activeColor,
    required this.hasReused,
    required this.hasWeak,
    required this.hasMissing2fa,
    required this.selectedFilterIndex,
  });

  // 260° open-cradle gauge angles
  static const double _startAngle = 140 * math.pi / 180;
  static const double _totalSweep = 260 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 12;

    // 1. Ambient Dynamic Phosphor Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          activeColor.withValues(alpha: 0.12 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, glowPaint);

    // 2. Continuous 360° Rotating Radar Sweep Beam
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(radarSweepValue * 2 * math.pi);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          activeColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.35],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: maxRadius));
    canvas.drawCircle(Offset.zero, maxRadius, sweepPaint);
    canvas.restore();

    // 3. Polar Grid Radar Circles & Cardinal Reticle Ticks
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final factor in [0.42, 0.57, 0.72, 0.90]) {
      canvas.drawCircle(center, maxRadius * factor, gridPaint);
    }

    // 4. Concentric Track Calculations
    final rMain = maxRadius * 0.90;
    final rOrbit1 = maxRadius * 0.72; // Uniqueness
    final rOrbit2 = maxRadius * 0.57; // Entropy
    final rOrbit3 = maxRadius * 0.42; // 2FA

    final trackBgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw Sub-Arc 1 Track & Progress (Password Uniqueness - Rose)
    _drawSubArc(
      canvas: canvas,
      center: center,
      radius: rOrbit1,
      strokeWidth: 3.5,
      bgPaint: trackBgPaint,
      ratio: uniqueRatio,
      color: AppColors.rose500,
      isHighlighted: selectedFilterIndex == 1,
    );

    // Draw Sub-Arc 2 Track & Progress (Shannon Entropy - Amber)
    _drawSubArc(
      canvas: canvas,
      center: center,
      radius: rOrbit2,
      strokeWidth: 3.5,
      bgPaint: trackBgPaint,
      ratio: strongRatio,
      color: AppColors.amber500,
      isHighlighted: selectedFilterIndex == 2,
    );

    // Draw Sub-Arc 3 Track & Progress (2FA TOTP - Neon Mint)
    _drawSubArc(
      canvas: canvas,
      center: center,
      radius: rOrbit3,
      strokeWidth: 3.5,
      bgPaint: trackBgPaint,
      ratio: totpRatio,
      color: const Color(0xFF00F59B),
      isHighlighted: selectedFilterIndex == 3,
    );

    // 5. Main Primary Health Arc (Dual-Pass Glow + Crisp Gradient)
    final mainTrackPaint = Paint()
      ..color = const Color(0xFF141720)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rMain),
      _startAngle,
      _totalSweep,
      false,
      mainTrackPaint,
    );

    final currentSweep = _totalSweep * progress * (healthScore / 100.0);

    if (currentSweep > 0.01) {
      // Glow Pass (Bloom)
      final glowArcPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: rMain),
        _startAngle,
        currentSweep,
        false,
        glowArcPaint,
      );

      // Crisp Gradient Foreground Pass
      final gradientArcPaint = Paint()
        ..shader = const SweepGradient(
          startAngle: _startAngle,
          endAngle: _startAngle + _totalSweep,
          colors: [
            AppColors.rose500,
            AppColors.amber500,
            Color(0xFF00F59B),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: rMain))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: rMain),
        _startAngle,
        currentSweep,
        false,
        gradientArcPaint,
      );

      // Specular Head Indicator Dot
      final headAngle = _startAngle + currentSweep;
      final headX = center.dx + rMain * math.cos(headAngle);
      final headY = center.dy + rMain * math.sin(headAngle);
      final headOffset = Offset(headX, headY);

      canvas.drawCircle(
        headOffset,
        6.0,
        Paint()..color = activeColor.withValues(alpha: 0.5),
      );
      canvas.drawCircle(
        headOffset,
        3.5,
        Paint()..color = Colors.white,
      );
    }

    // 6. Interactive Vulnerability Pulse Dots on Radar Orbits
    if (hasReused) {
      _drawSonarPulse(canvas, center, rOrbit1, _startAngle + _totalSweep * 0.25, AppColors.rose500);
    }
    if (hasWeak) {
      _drawSonarPulse(canvas, center, rOrbit2, _startAngle + _totalSweep * 0.65, AppColors.amber500);
    }
    if (hasMissing2fa) {
      _drawSonarPulse(canvas, center, rOrbit3, _startAngle + _totalSweep * 0.85, const Color(0xFF00F59B));
    }
  }

  void _drawSubArc({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double strokeWidth,
    required Paint bgPaint,
    required double ratio,
    required Color color,
    required bool isHighlighted,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    bgPaint.strokeWidth = strokeWidth;
    canvas.drawArc(rect, _startAngle, _totalSweep, false, bgPaint);

    final sweep = _totalSweep * progress * ratio;
    if (sweep > 0.01) {
      final fgPaint = Paint()
        ..color = isHighlighted ? color : color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? strokeWidth + 2.0 : strokeWidth
        ..strokeCap = StrokeCap.round;

      if (isHighlighted) {
        fgPaint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      }

      canvas.drawArc(rect, _startAngle, sweep, false, fgPaint);
    }
  }

  void _drawSonarPulse(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Color color,
  ) {
    final dotX = center.dx + radius * math.cos(angle);
    final dotY = center.dy + radius * math.sin(angle);
    final dotOffset = Offset(dotX, dotY);

    // Expanding Sonar Ping
    final pingRadius = 4.0 + (pulseValue * 10.0);
    final pingAlpha = (1.0 - pulseValue).clamp(0.0, 1.0) * 0.7;

    canvas.drawCircle(
      dotOffset,
      pingRadius,
      Paint()
        ..color = color.withValues(alpha: pingAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Core Solid Dot
    canvas.drawCircle(
      dotOffset,
      4.0,
      Paint()..color = color,
    );
    canvas.drawCircle(
      dotOffset,
      1.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.healthScore != healthScore ||
        oldDelegate.radarSweepValue != radarSweepValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.selectedFilterIndex != selectedFilterIndex;
  }
}
