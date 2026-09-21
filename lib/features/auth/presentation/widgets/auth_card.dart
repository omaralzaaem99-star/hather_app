import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';

/// Auth form panel. Login uses [glass]; register/other use solid #161717.
class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.child,
    super.key,
    this.showHandle = true,
    this.glass = false,
    this.bottomInset = 0,
    this.padding,
    this.margin,
  });

  final Widget child;
  final bool showHandle;

  /// When true: frosted transparent panel (login reference style).
  final bool glass;

  /// Extra bottom padding inside the card (room for create-account notch).
  final double bottomInset;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = glass
        ? AppDimensions.radiusAuthGlass
        : AppDimensions.radiusAuthCard;
    final resolvedPadding =
        padding ??
        EdgeInsets.fromLTRB(
          22,
          glass ? 26 : 20,
          22,
          glass ? 24 + bottomInset : 22,
        );

    final panel = Container(
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: glass ? AppColors.glassFill : AppColors.authCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glass ? AppColors.glassBorder : AppColors.authPanelBorder,
          width: glass ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            Container(
              width: AppDimensions.handleWidth,
              height: AppDimensions.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.icon.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );

    return Container(
      width: double.infinity,
      margin:
          margin ??
          const EdgeInsets.symmetric(
            horizontal: AppDimensions.authHorizontalMargin,
          ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: glass ? 0.14 : 0.16),
            blurRadius: glass ? 34 : 18,
            offset: Offset(0, glass ? 18 : 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: glass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: panel,
              )
            : Material(color: Colors.transparent, child: panel),
      ),
    );
  }
}
