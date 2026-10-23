import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/expressive/expressive_vertical_slider.dart';

/// Screen 5: Password Generator Screen
///
/// Features monospace password display, entropy evaluation gauge, 1-tap copy,
/// 4 character set toggles, and tactile vertical ladder length slider.
class PasswordGeneratorScreen extends ConsumerStatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  ConsumerState<PasswordGeneratorScreen> createState() => _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends ConsumerState<PasswordGeneratorScreen> {
  int _length = 16;
  bool _useUpper = true;
  bool _useLower = true;
  bool _useNumbers = true;
  bool _useSymbols = true;

  String _generatedPassword = '';

  /// Number of currently active character-set toggles.
  int get _enabledCount =>
      (_useUpper ? 1 : 0) +
      (_useLower ? 1 : 0) +
      (_useNumbers ? 1 : 0) +
      (_useSymbols ? 1 : 0);

  /// True when this toggle can be turned OFF — i.e. there are more than 2
  /// options currently enabled (so at least 2 will remain after disabling).
  bool _canDisable(bool currentValue) => !currentValue || _enabledCount > 2;

  /// Shows a brief snackbar when the user tries to disable a locked switch.
  void _showMinimumOptionsWarning() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'At least 2 options must stay enabled.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    final upper = _useUpper ? 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' : '';
    final lower = _useLower ? 'abcdefghijklmnopqrstuvwxyz' : '';
    final numbers = _useNumbers ? '0123456789' : '';
    final symbols = _useSymbols ? '!@#\$%^&*()_+-=[]{}|;:,.<>?' : '';

    final pool = '$upper$lower$numbers$symbols';
    if (pool.isEmpty) {
      setState(() => _generatedPassword = '');
      return;
    }

    final random = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < _length; i++) {
      buffer.write(pool[random.nextInt(pool.length)]);
    }

    setState(() {
      _generatedPassword = buffer.toString();
    });
  }

  String get _strengthLabel {
    if (_length < 10 || (!_useSymbols && !_useNumbers)) {
      return 'Weak';
    } else if (_length < 14 || !_useSymbols) {
      return 'Medium';
    } else {
      return 'Strong';
    }
  }

  Color get _strengthColor {
    switch (_strengthLabel) {
      case 'Weak':
        return AppColors.rose500;
      case 'Medium':
        return AppColors.amber500;
      default:
        return AppColors.emerald500;
    }
  }

  void _copyToClipboard() {
    if (_generatedPassword.isEmpty) return;
    HapticFeedback.lightImpact();
    ClipboardSecurityService.copySecure(
      context: context,
      ref: ref,
      text: _generatedPassword,
      label: 'Generated Password',
      isSensitive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Text(
                  'Generator',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Generated Password Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: borderCol, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 60 : 15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Monospace Password — fixed height, font scales down for long passwords
                      SizedBox(
                        height: 48,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SelectableText(
                            _generatedPassword,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Entropy Strength Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _strengthColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _strengthLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _strengthColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Actions: Regenerate & Copy
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _regenerate,
                            style: IconButton.styleFrom(
                              backgroundColor: inputBg,
                              foregroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.all(14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 24),
                            tooltip: 'Regenerate',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _copyToClipboard,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              label: const Text('Copy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Options Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Options',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'LENGTH: $_length',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dual Options Section (Toggles on Left, Vertical Ruler on Right)
                SizedBox(
                  height: 270,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Toggles Column
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: borderCol),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: _ToggleTile(
                                  title: 'Uppercase',
                                  subtitle: 'A-Z',
                                  value: _useUpper,
                                  isLocked: _useUpper && _enabledCount <= 2,
                                  onChanged: (val) {
                                    if (!_canDisable(_useUpper)) {
                                      _showMinimumOptionsWarning();
                                      return;
                                    }
                                    setState(() => _useUpper = val);
                                    _regenerate();
                                  },
                                ),
                              ),
                              Divider(height: 1, color: borderCol),
                              Expanded(
                                child: _ToggleTile(
                                  title: 'Lowercase',
                                  subtitle: 'a-z',
                                  value: _useLower,
                                  isLocked: _useLower && _enabledCount <= 2,
                                  onChanged: (val) {
                                    if (!_canDisable(_useLower)) {
                                      _showMinimumOptionsWarning();
                                      return;
                                    }
                                    setState(() => _useLower = val);
                                    _regenerate();
                                  },
                                ),
                              ),
                              Divider(height: 1, color: borderCol),
                              Expanded(
                                child: _ToggleTile(
                                  title: 'Numbers',
                                  subtitle: '0-9',
                                  value: _useNumbers,
                                  isLocked: _useNumbers && _enabledCount <= 2,
                                  onChanged: (val) {
                                    if (!_canDisable(_useNumbers)) {
                                      _showMinimumOptionsWarning();
                                      return;
                                    }
                                    setState(() => _useNumbers = val);
                                    _regenerate();
                                  },
                                ),
                              ),
                              Divider(height: 1, color: borderCol),
                              Expanded(
                                child: _ToggleTile(
                                  title: 'Symbols',
                                  subtitle: '!@#\$%^&*',
                                  value: _useSymbols,
                                  isLocked: _useSymbols && _enabledCount <= 2,
                                  onChanged: (val) {
                                    if (!_canDisable(_useSymbols)) {
                                      _showMinimumOptionsWarning();
                                      return;
                                    }
                                    setState(() => _useSymbols = val);
                                    _regenerate();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Vertical Ruler Ladder Slider (fixed height matches SizedBox)
                      ExpressiveVerticalMotionSlider(
                        value: _length,
                        min: 8,
                        max: 32,
                        height: 270,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _length = val);
                          _regenerate();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool isLocked;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label + optional lock icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLocked ? mutedColor : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
              if (isLocked) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock_rounded, size: 12, color: mutedColor),
              ],
            ],
          ),

          // Switch — greyed and intercepted when locked
          GestureDetector(
            // When locked & ON, intercept the tap to show the warning instead.
            onTap: isLocked ? () => onChanged(false) : null,
            child: Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: Switch.adaptive(
                value: value,
                activeThumbColor: AppColors.primaryBlue,
                activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                // When locked, pass null so the switch itself is non-interactive;
                // the GestureDetector above handles the tap instead.
                onChanged: isLocked ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
