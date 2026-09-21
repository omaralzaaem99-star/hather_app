import 'package:flutter/material.dart';

/// Semantic palette that changes between dark and light mode.
@immutable
class HatherThemeColors extends ThemeExtension<HatherThemeColors> {
  const HatherThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderSubtle,
    required this.inputFill,
    required this.divider,
    required this.authCard,
    required this.glassFill,
    required this.glassBorder,
    required this.authPanelBorder,
    required this.errorSurface,
    required this.errorBorder,
    required this.navBar,
    required this.overlay,
    required this.accent,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderSubtle;
  final Color inputFill;
  final Color divider;
  final Color authCard;
  final Color glassFill;
  final Color glassBorder;
  final Color authPanelBorder;
  final Color errorSurface;
  final Color errorBorder;
  final Color navBar;
  final Color overlay;
  /// Icons, links, and secondary green text.
  final Color accent;
  /// Completed / success status text and badges.
  final Color success;

  static const dark = HatherThemeColors(
    background: Color(0xFF161717),
    surface: Color(0xFF1E1F1F),
    surfaceElevated: Color(0xFF232826),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB8BABA),
    textMuted: Color(0xFF8A8C8C),
    border: Color(0xFF3A3F3C),
    borderSubtle: Color(0x66FFFFFF),
    inputFill: Color(0x991A3328),
    divider: Color(0xFF2A2B2B),
    authCard: Color(0xFF161717),
    glassFill: Color(0x08FFFFFF),
    glassBorder: Color(0x61FFFFFF),
    authPanelBorder: Color(0x38FFFFFF),
    errorSurface: Color(0xFF3A1A1A),
    errorBorder: Color(0xFFFF8A8A),
    navBar: Color(0xFF111314),
    overlay: Color(0x99000000),
    accent: Color(0xFF9AD4B8),
    success: Color(0xFF4CAF7A),
  );

  static const light = HatherThemeColors(
    background: Color(0xFFF4F6F5),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F3F2),
    textPrimary: Color(0xFF1A1C1B),
    textSecondary: Color(0xFF4A4F4D),
    textMuted: Color(0xFF7A807E),
    border: Color(0xFFD5DAD8),
    borderSubtle: Color(0x33000000),
    inputFill: Color(0xFFF7FAF9),
    divider: Color(0xFFE4E8E7),
    authCard: Color(0xFFFFFFFF),
    glassFill: Color(0xEBFFFFFF),
    glassBorder: Color(0x4D144D37),
    authPanelBorder: Color(0x26144D37),
    errorSurface: Color(0xFFFFEBEB),
    errorBorder: Color(0xFFE85C5C),
    navBar: Color(0xFF144D37),
    overlay: Color(0x66000000),
    // Stronger greens for readable contrast on light surfaces.
    accent: Color(0xFF1A5F44),
    success: Color(0xFF1B6B47),
  );

  @override
  HatherThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderSubtle,
    Color? inputFill,
    Color? divider,
    Color? authCard,
    Color? glassFill,
    Color? glassBorder,
    Color? authPanelBorder,
    Color? errorSurface,
    Color? errorBorder,
    Color? navBar,
    Color? overlay,
    Color? accent,
    Color? success,
  }) {
    return HatherThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      inputFill: inputFill ?? this.inputFill,
      divider: divider ?? this.divider,
      authCard: authCard ?? this.authCard,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      authPanelBorder: authPanelBorder ?? this.authPanelBorder,
      errorSurface: errorSurface ?? this.errorSurface,
      errorBorder: errorBorder ?? this.errorBorder,
      navBar: navBar ?? this.navBar,
      overlay: overlay ?? this.overlay,
      accent: accent ?? this.accent,
      success: success ?? this.success,
    );
  }

  @override
  HatherThemeColors lerp(ThemeExtension<HatherThemeColors>? other, double t) {
    if (other is! HatherThemeColors) return this;
    Color lerpColor(Color a, Color b) => Color.lerp(a, b, t)!;
    return HatherThemeColors(
      background: lerpColor(background, other.background),
      surface: lerpColor(surface, other.surface),
      surfaceElevated: lerpColor(surfaceElevated, other.surfaceElevated),
      textPrimary: lerpColor(textPrimary, other.textPrimary),
      textSecondary: lerpColor(textSecondary, other.textSecondary),
      textMuted: lerpColor(textMuted, other.textMuted),
      border: lerpColor(border, other.border),
      borderSubtle: lerpColor(borderSubtle, other.borderSubtle),
      inputFill: lerpColor(inputFill, other.inputFill),
      divider: lerpColor(divider, other.divider),
      authCard: lerpColor(authCard, other.authCard),
      glassFill: lerpColor(glassFill, other.glassFill),
      glassBorder: lerpColor(glassBorder, other.glassBorder),
      authPanelBorder: lerpColor(authPanelBorder, other.authPanelBorder),
      errorSurface: lerpColor(errorSurface, other.errorSurface),
      errorBorder: lerpColor(errorBorder, other.errorBorder),
      navBar: lerpColor(navBar, other.navBar),
      overlay: lerpColor(overlay, other.overlay),
      accent: lerpColor(accent, other.accent),
      success: lerpColor(success, other.success),
    );
  }
}

extension HatherThemeContext on BuildContext {
  HatherThemeColors get hatherColors =>
      Theme.of(this).extension<HatherThemeColors>() ?? HatherThemeColors.dark;
}
