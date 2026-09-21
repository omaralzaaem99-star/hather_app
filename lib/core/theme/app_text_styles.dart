import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tokens — colors resolve via [AppColors.bind] at runtime.
class AppTextStyles {
  const AppTextStyles._();

  static TextStyle get brandTitle => TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.15,
        letterSpacing: 0.5,
        shadows: const [
          Shadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 3)),
        ],
      );

  static TextStyle get screenTitle => TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        height: 1.2,
        shadows: const [
          Shadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 3)),
        ],
      );

  static TextStyle get sectionTitle => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get bodyStrong => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
      );

  static TextStyle get link => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get linkAccent => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.icon,
      );

  static TextStyle get button => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onPrimary,
      );

  static TextStyle get input => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      );

  static TextStyle get error => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.error,
        height: 1.35,
      );

  static TextStyle get createAccountCta => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.icon,
      );
}
