import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';

class ErrorMessage extends StatelessWidget {
  const ErrorMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spaceSm),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          message,
          style: AppTextStyles.error,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}

class AuthFormErrorBanner extends StatelessWidget {
  const AuthFormErrorBanner({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMd,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.errorBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: AppTextStyles.error.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
