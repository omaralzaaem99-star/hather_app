import 'package:flutter/material.dart';
import 'package:hather_app/core/constants/auth_assets.dart';
import 'package:hather_app/core/theme/app_colors.dart';

/// Full-bleed auth background: photo + light dark overlay for readability.
class AuthHeroBackground extends StatelessWidget {
  const AuthHeroBackground({
    super.key,
    this.imageAsset = AuthAssets.background,
    this.alignment = Alignment.center,
  });

  final String imageAsset;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          alignment: alignment,
          errorBuilder: (context, error, stackTrace) =>
              const _FallbackBackdrop(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x14161717),
                Color(0x2E161717),
                Color(0x66161717),
                Color(0x99161717),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.primary.withValues(alpha: 0.06),
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.08),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FallbackBackdrop extends StatelessWidget {
  const _FallbackBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.primary.withValues(alpha: 0.35),
            AppColors.background,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Icon(
          Icons.local_shipping_outlined,
          size: 88,
          color: AppColors.icon.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}
