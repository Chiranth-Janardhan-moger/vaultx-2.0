import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/pressable_scale.dart';

/// Interactive Randomized Scrambled Keypad for Bank ATM PINs and UPI MPINs.
/// Scrambles digits 0-9 to prevent shoulder-surfing and screen smudge forensic attacks.
/// Renders large tactile digit dots with glowing bloom and smooth reveal wave.
class ScrambledPinKeypad extends StatefulWidget {
  final int pinLength;
  final String title;
  final String subtitle;
  final ValueChanged<String>? onPinChanged;
  final ValueChanged<String>? onCompleted;
  final String initialValue;

  const ScrambledPinKeypad({
    super.key,
    this.pinLength = 4,
    this.title = 'Enter Security PIN',
    this.subtitle = 'Positions are randomized for shoulder-surfing protection',
    this.onPinChanged,
    this.onCompleted,
    this.initialValue = '',
  });

  @override
  State<ScrambledPinKeypad> createState() => _ScrambledPinKeypadState();
}

class _ScrambledPinKeypadState extends State<ScrambledPinKeypad> {
  late List<int> _digits;
  String _enteredPin = '';
  bool _revealDigits = false;

  @override
  void initState() {
    super.initState();
    _enteredPin = widget.initialValue;
    _scrambleKeypad();
  }

  void _scrambleKeypad() {
    final list = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    list.shuffle(Random.secure());
    setState(() {
      _digits = list;
    });
  }

  void _onDigitPressed(int digit) {
    if (_enteredPin.length >= widget.pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit.toString();
    });
    widget.onPinChanged?.call(_enteredPin);
    if (_enteredPin.length == widget.pinLength) {
      widget.onCompleted?.call(_enteredPin);
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
    widget.onPinChanged?.call(_enteredPin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textCol = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title & Subtitle
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: mutedCol),
          ),
          const SizedBox(height: 24),

          // Tactile Digit Dots Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.pinLength, (index) {
              final isFilled = index < _enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? AppColors.primaryBlue
                      : (isDark ? Colors.white12 : Colors.black12),
                  border: Border.all(
                    color: isFilled
                        ? AppColors.primaryBlue.withAlpha(180)
                        : (isDark ? Colors.white24 : Colors.black26),
                    width: 1.5,
                  ),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: AppColors.primaryBlue.withAlpha(isDark ? 120 : 60),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: _revealDigits && isFilled
                    ? Text(
                        _enteredPin[index],
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      )
                    : null,
              );
            }),
          ),
          const SizedBox(height: 16),

          // Scramble & Reveal Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _scrambleKeypad();
                },
                icon: const Icon(Icons.shuffle_rounded, size: 16),
                label: const Text('Scramble Grid'),
                style: TextButton.styleFrom(
                  foregroundColor: mutedCol,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _revealDigits = !_revealDigits);
                },
                icon: Icon(
                  _revealDigits ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 16,
                ),
                label: Text(_revealDigits ? 'Mask' : 'Reveal'),
                style: TextButton.styleFrom(
                  foregroundColor: mutedCol,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3x4 Scrambled Keypad Grid
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                _buildKeypadRow([_digits[0], _digits[1], _digits[2]], cardBg, borderCol, textCol),
                const SizedBox(height: 10),
                _buildKeypadRow([_digits[3], _digits[4], _digits[5]], cardBg, borderCol, textCol),
                const SizedBox(height: 10),
                _buildKeypadRow([_digits[6], _digits[7], _digits[8]], cardBg, borderCol, textCol),
                const SizedBox(height: 10),
                // Bottom row: Clear all, 10th digit, Backspace
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Clear Button
                    _buildActionButton(
                      icon: Icons.refresh_rounded,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        setState(() => _enteredPin = '');
                        widget.onPinChanged?.call('');
                      },
                      cardBg: cardBg,
                      borderCol: borderCol,
                    ),
                    // 10th randomized digit
                    _buildDigitButton(_digits[9], cardBg, borderCol, textCol),
                    // Backspace Button
                    _buildActionButton(
                      icon: Icons.backspace_outlined,
                      onTap: _onBackspace,
                      cardBg: cardBg,
                      borderCol: borderCol,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<int> rowDigits, Color cardBg, Color borderCol, Color textCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: rowDigits.map((d) => _buildDigitButton(d, cardBg, borderCol, textCol)).toList(),
    );
  }

  Widget _buildDigitButton(int digit, Color cardBg, Color borderCol, Color textCol) {
    return PressableScale(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 68,
        height: 56,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.0),
        ),
        alignment: Alignment.center,
        child: Text(
          digit.toString(),
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textCol,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color cardBg,
    required Color borderCol,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 56,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.0),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20),
      ),
    );
  }
}
