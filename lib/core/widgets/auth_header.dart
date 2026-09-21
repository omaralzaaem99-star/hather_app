import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.greeting,
  });

  final String title;
  final String? subtitle;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (greeting != null) ...[
          Text(greeting!, style: AppTextStyles.caption),
          const SizedBox(height: AppDimensions.spaceXs),
        ],
        Text(
          title,
          style: AppTextStyles.screenTitle,
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({required this.name, super.key, this.compact = false});

  final String name;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: (compact
              ? AppTextStyles.brandTitle.copyWith(fontSize: 34)
              : AppTextStyles.brandTitle)
          .copyWith(
        color: AppColors.onPrimary,
        shadows: const [],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Official app logo image — use for splash and login only.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 100});

  static const assetPath = 'assets/images/app_icon.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: size,
      width: size,
      fit: BoxFit.contain,
    );
  }
}
