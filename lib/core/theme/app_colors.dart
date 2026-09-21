import 'package:flutter/material.dart';

import 'hather_theme_colors.dart';

/// Brand + semantic colors for حاضر.
///
/// Brand colors are fixed. Semantic colors follow the active theme via [bind].
class AppColors {
  const AppColors._();

  static HatherThemeColors _semantic = HatherThemeColors.dark;

  /// Sync semantic getters with [brightness] — call from [MaterialApp.builder].
  static void bind(Brightness brightness) {
    _semantic = brightness == Brightness.light
        ? HatherThemeColors.light
        : HatherThemeColors.dark;
  }

  /// Active semantic palette (for tests/diagnostics).
  static HatherThemeColors get semantic => _semantic;

  // —— Brand (fixed) ——
  static const Color primary = Color(0xFF144D37);
  static const Color primaryHover = Color(0xFF1A5F44);
  static const Color onPrimary = Color(0xFFFFFFFF);
  /// Theme-aware mint accent — icons, links, active status (light: darker green).
  static Color get icon => _semantic.accent;
  /// Theme-aware success — completed orders, badges (light: darker green).
  static Color get success => _semantic.success;
  static const Color error = Color(0xFFFF5C5C);
  static const Color pendingOrder = Color(0xFFE86A6A);
  static const Color shadow = Color(0xFF000000);
  static const Color borderFocused = Color(0xFF144D37);
  static const Color whatsApp = Color(0xFF25D366);

  // —— Semantic (theme-aware) ——
  static Color get background => _semantic.background;
  static Color get surface => _semantic.surface;
  static Color get surfaceElevated => _semantic.surfaceElevated;
  static Color get textPrimary => _semantic.textPrimary;
  static Color get textSecondary => _semantic.textSecondary;
  static Color get textMuted => _semantic.textMuted;
  static Color get border => _semantic.border;
  static Color get borderSubtle => _semantic.borderSubtle;
  static Color get inputFill => _semantic.inputFill;
  static Color get divider => _semantic.divider;
  static Color get authCard => _semantic.authCard;
  static Color get glassFill => _semantic.glassFill;
  static Color get glassBorder => _semantic.glassBorder;
  static Color get authPanelBorder => _semantic.authPanelBorder;
  static Color get errorSurface => _semantic.errorSurface;
  static Color get errorBorder => _semantic.errorBorder;
  static Color get navBar => _semantic.navBar;
  static Color get overlay => _semantic.overlay;
}
