import 'package:flutter/material.dart';

/// Shared spacing, radii, and sizes.
class AppDimensions {
  const AppDimensions._();

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusAuthCard = 36;
  static const double radiusAuthGlass = 46;
  static const double radiusPill = 40;

  static const double buttonHeight = 56;
  static const double inputHeight = 56;
  static const double otpBoxSize = 48;
  static const double iconSize = 22;
  static const double handleWidth = 40;
  static const double handleHeight = 4;

  static const double authHorizontalMargin = 22;
  static const double authBrandTopFactor = 0.06;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(24, 24, 24, 28);

  /// Scroll/list padding with dynamic bottom inset for the system nav bar.
  static EdgeInsets scrollPadding(
    BuildContext context, {
    double left = 20,
    double top = 16,
    double right = 20,
    double bottom = 24,
  }) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return EdgeInsets.fromLTRB(left, top, right, bottom + bottomInset);
  }
}
