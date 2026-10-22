import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic design tokens for VaultX
class AppColors {
  AppColors._();

  // Core Brand Accents
  static const Color primaryBlue = Color(0xFF0080FF);
  static const Color brandPurple = Color(0xFFA855F7);

  // Status & Security Semantics
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald950 = Color(0xFF022C22);

  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber400 = Color(0xFFFBBF24);

  static const Color rose500 = Color(0xFFEF4444);
  static const Color rose400 = Color(0xFFF87171);
  static const Color rose950 = Color(0xFF450A0A);

  // Dark Theme Neutral Surfaces
  static const Color darkBackground = Color(0xFF020617);
  static const Color darkCardSurface = Color(0xFF191C1E);
  static const Color darkInputSurface = Color(0xFF272A2C);
  static const Color darkBorder = Color(0x1FFFFFFF);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Light Theme Neutral Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCardSurface = Color(0xFFFFFFFF);
  static const Color lightInputSurface = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);
}

/// Paired Material 3 ColorSchemes and Theme configurations
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryBlue,
      onPrimary: Colors.white,
      secondary: AppColors.brandPurple,
      onSecondary: Colors.white,
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainer: AppColors.darkCardSurface,
      surfaceContainerHigh: AppColors.darkInputSurface,
      error: AppColors.rose500,
      onError: Colors.white,
      outline: AppColors.darkTextMuted,
      outlineVariant: AppColors.darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkCardSurface,
      dividerColor: AppColors.darkBorder,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.darkBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primaryBlue,
      onPrimary: Colors.white,
      secondary: AppColors.brandPurple,
      onSecondary: Colors.white,
      surface: AppColors.lightBackground,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainer: AppColors.lightCardSurface,
      surfaceContainerHigh: AppColors.lightInputSurface,
      error: AppColors.rose500,
      onError: Colors.white,
      outline: AppColors.lightTextMuted,
      outlineVariant: AppColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightCardSurface,
      dividerColor: AppColors.lightBorder,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.lightBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
        ),
      ),
    );
  }
}
