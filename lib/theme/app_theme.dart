import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema principal do SeusDADOS Client
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary600,
        onPrimary: Colors.white,
        secondary: AppColors.gray600,
        onSecondary: Colors.white,
        error: AppColors.danger600,
        onError: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.gray900,
        surfaceContainerHighest: AppColors.gray100,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.gray50,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
        shadowColor: AppColors.shadowLight,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary600,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary600,
          side: const BorderSide(color: AppColors.primary600, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary600,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger600),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger600, width: 2),
        ),
        labelStyle: AppTextStyles.inputLabel,
        hintStyle: AppTextStyles.input.copyWith(color: AppColors.gray400),
        errorStyle: AppTextStyles.inputError,
        helperStyle: AppTextStyles.inputHelper,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.gray100,
        selectedColor: AppColors.primary100,
        labelStyle: AppTextStyles.badge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.gray200,
        thickness: 1,
        space: 1,
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary600,
        linearTrackColor: AppColors.gray200,
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall: AppTextStyles.h3,
        titleLarge: AppTextStyles.h4,
        titleMedium: AppTextStyles.h5,
        titleSmall: AppTextStyles.h6,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.buttonLarge,
        labelMedium: AppTextStyles.buttonMedium,
        labelSmall: AppTextStyles.buttonSmall,
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary600,
        unselectedLabelColor: AppColors.gray500,
        indicatorColor: AppColors.primary600,
        labelStyle: AppTextStyles.buttonMedium,
        unselectedLabelStyle: AppTextStyles.buttonMedium,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: AppTextStyles.h4,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.gray800,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary400,
        onPrimary: AppColors.gray900,
        secondary: AppColors.gray400,
        onSecondary: AppColors.gray900,
        error: AppColors.danger500,
        onError: Colors.white,
        surface: AppColors.gray900,
        onSurface: AppColors.gray100,
        surfaceContainerHighest: AppColors.gray800,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.gray900,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.gray900,
        foregroundColor: AppColors.gray100,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.gray100,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: AppColors.gray800,
        shadowColor: Colors.transparent,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary600,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gray100,
          side: const BorderSide(color: AppColors.gray600, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.gray800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger500),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger500, width: 2),
        ),
        labelStyle: AppTextStyles.inputLabel.copyWith(color: AppColors.gray200),
        hintStyle: AppTextStyles.input.copyWith(color: AppColors.gray400),
        errorStyle: AppTextStyles.inputError,
        helperStyle:
            AppTextStyles.inputHelper.copyWith(color: AppColors.gray400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.gray700,
        thickness: 1,
        space: 1,
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary400,
        linearTrackColor: AppColors.gray700,
      ),

      // Text Theme (cores adaptadas ao modo escuro)
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display.copyWith(color: AppColors.gray100),
        headlineLarge: AppTextStyles.h1.copyWith(color: AppColors.gray100),
        headlineMedium: AppTextStyles.h2.copyWith(color: AppColors.gray100),
        headlineSmall: AppTextStyles.h3.copyWith(color: AppColors.gray100),
        titleLarge: AppTextStyles.h4.copyWith(color: AppColors.gray100),
        titleMedium: AppTextStyles.h5.copyWith(color: AppColors.gray100),
        titleSmall: AppTextStyles.h6.copyWith(color: AppColors.gray100),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.gray200),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray200),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.gray300),
        labelLarge: AppTextStyles.buttonLarge,
        labelMedium: AppTextStyles.buttonMedium,
        labelSmall: AppTextStyles.buttonSmall,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.gray800,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.gray100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
