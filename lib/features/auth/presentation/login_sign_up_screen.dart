import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/settings/presentation/providers/biometric_preference_provider.dart';

enum AuthMode { login, signup }

/// Screen 1: Login / Sign Up Screen
///
/// Implements dual Log In / Sign Up modes, master password entry with unmasking,
/// biometric quick unlock gate, and zero-knowledge badge per Apple HIG standards.
class LoginSignUpScreen extends ConsumerStatefulWidget {
  final VoidCallback? onAuthenticated;

  const LoginSignUpScreen({super.key, this.onAuthenticated});

  @override
  ConsumerState<LoginSignUpScreen> createState() => _LoginSignUpScreenState();
}

class _LoginSignUpScreenState extends ConsumerState<LoginSignUpScreen> {
  AuthMode _mode = AuthMode.login;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _errorMessage;
  bool _hasAutoPrompted = false;

  @override
  void initState() {
    super.initState();
    final hasKey = ref.read(authSessionProvider).hasMasterKey;
    if (!hasKey) {
      _mode = AuthMode.signup;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoPromptBiometrics();
    });
  }

  void _checkAndAutoPromptBiometrics() {
    if (_hasAutoPrompted || _isLoading || _mode != AuthMode.login) return;
    final authState = ref.read(authSessionProvider);
    final bioEnabled = ref.read(biometricPreferenceProvider);
    if (authState.hasMasterKey && authState.isBiometricsAvailable && bioEnabled && !authState.isAuthenticated) {
      _hasAutoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(authSessionProvider).isAuthenticated) {
          _triggerBiometrics();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your master password.');
      return;
    }

    if (_mode == AuthMode.signup) {
      if (password.length < 8) {
        setState(() => _errorMessage = 'Master password must be at least 8 characters.');
        return;
      }
      if (password != _confirmController.text) {
        setState(() => _errorMessage = 'Passwords do not match.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(authSessionProvider.notifier);
    bool success;

    if (_mode == AuthMode.signup) {
      success = await notifier.setupMasterPassword(password);
    } else {
      success = await notifier.unlockWithMasterPassword(password);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        if (!mounted) return;
        HappyFeedback.show(
          context,
          message: 'Vault unlocked successfully',
          duration: const Duration(milliseconds: 1400),
        );
        widget.onAuthenticated?.call();
      } else {
        await HapticFeedback.heavyImpact();
        final err = ref.read(authSessionProvider).errorMessage;
        setState(() => _errorMessage = err ?? 'Authentication failed.');
      }
    }
  }

  void _triggerBiometrics() async {
    final authState = ref.read(authSessionProvider);
    final bioEnabled = ref.read(biometricPreferenceProvider);

    if (!authState.isBiometricsAvailable) {
      setState(() => _errorMessage = 'No biometrics enrolled on this device.');
      return;
    }
    if (!bioEnabled) {
      setState(() => _errorMessage = 'Biometric unlock is disabled. Enable it in Settings.');
      return;
    }

    final notifier = ref.read(authSessionProvider.notifier);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await notifier.unlockWithBiometrics();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        HappyFeedback.show(
          context,
          message: 'Vault unlocked successfully',
          duration: const Duration(milliseconds: 1400),
        );
        widget.onAuthenticated?.call();
      } else {
        unawaited(HapticFeedback.lightImpact());
        final err = ref.read(authSessionProvider).errorMessage;
        if (err != null) {
          setState(() => _errorMessage = err);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthSessionState>(authSessionProvider, (prev, next) {
      if (prev?.hasMasterKey != next.hasMasterKey) {
        if (!next.hasMasterKey && _mode != AuthMode.signup) {
          setState(() => _mode = AuthMode.signup);
        } else if (next.hasMasterKey && _mode != AuthMode.login) {
          setState(() => _mode = AuthMode.login);
        }
      }
      if (prev?.isAuthenticated == true && !next.isAuthenticated) {
        _hasAutoPrompted = false;
        _checkAndAutoPromptBiometrics();
      } else if (next.hasMasterKey && next.isBiometricsAvailable && !next.isAuthenticated) {
        _checkAndAutoPromptBiometrics();
      }
    });

    ref.listen<bool>(biometricPreferenceProvider, (prev, next) {
      if (next) {
        _checkAndAutoPromptBiometrics();
      }
    });

    final authState = ref.watch(authSessionProvider);
    final bioEnabled = ref.watch(biometricPreferenceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hero Identity Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.brandPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withAlpha(80),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Brand Wordmark
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.brandPurple],
                    ).createShader(bounds),
                    child: const Text(
                      'VaultX',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your mind, secured.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Container Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderCol, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 60 : 15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmented Mode Selector
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ModeButton(
                                  label: 'Log In',
                                  isSelected: _mode == AuthMode.login,
                                  onTap: () {
                                    setState(() {
                                      _mode = AuthMode.login;
                                      _errorMessage = null;
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: _ModeButton(
                                  label: 'Sign Up',
                                  isSelected: _mode == AuthMode.signup,
                                  onTap: () {
                                    setState(() {
                                      _mode = AuthMode.signup;
                                      _errorMessage = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.rose950.withAlpha(120),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.rose500.withAlpha(100)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.rose400, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD1D1),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Master Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: _mode == AuthMode.login ? 'Master Password' : 'Create Master Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),

                        // Confirm Password (Sign Up only)
                        if (_mode == AuthMode.signup) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              hintText: 'Confirm Master Password',
                              prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirm = !_obscureConfirm);
                                },
                              ),
                              filled: true,
                              fillColor: inputBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Primary Submit CTA Button
                        if (_mode == AuthMode.login &&
                            authState.hasMasterKey &&
                            authState.isBiometricsAvailable &&
                            bioEnabled) ...[
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _triggerBiometrics,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.fingerprint_rounded, size: 24),
                            label: const Text(
                              'Unlock with Fingerprint',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderCol),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                    ),
                                  )
                                : const Text(
                                    'Unlock with Password',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _mode == AuthMode.login ? 'Unlock Vault' : 'Create Vault',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                          if (_mode == AuthMode.login &&
                              authState.hasMasterKey &&
                              authState.isBiometricsAvailable &&
                              !bioEnabled) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(44, 48),
                                side: BorderSide(color: borderCol),
                                shape: const StadiumBorder(),
                              ),
                              icon: const Icon(Icons.fingerprint_rounded, size: 22),
                              label: const Text(
                                'Biometrics Disabled in Settings',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Zero-Knowledge Encryption Assurance Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        size: 16,
                        color: AppColors.emerald500,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '100% On-Device Zero-Knowledge Vault',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? AppColors.darkCardSurface : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }
}
