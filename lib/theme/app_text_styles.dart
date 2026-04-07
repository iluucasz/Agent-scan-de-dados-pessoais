import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Estilos de texto do SeusDADOS Client
class AppTextStyles {
  // Display
  static const TextStyle display = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: AppColors.gray900,
    height: 1.2,
  );

  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.gray900,
    height: 1.25,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.gray900,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.gray900,
    height: 1.35,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.gray900,
    height: 1.4,
  );

  static const TextStyle h5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.gray900,
    height: 1.45,
  );

  static const TextStyle h6 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.gray900,
    height: 1.5,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: AppColors.gray700,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.gray700,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.gray600,
    height: 1.5,
  );

  // Caption/Helper
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.gray500,
    height: 1.5,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.gray500,
    letterSpacing: 1.5,
    height: 1.5,
  );

  // Button
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  // Badge
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // Input
  static const TextStyle input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.gray900,
    height: 1.5,
  );

  static const TextStyle inputLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.gray700,
    height: 1.5,
  );

  static const TextStyle inputHelper = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.gray500,
    height: 1.5,
  );

  static const TextStyle inputError = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.danger600,
    height: 1.5,
  );
}
