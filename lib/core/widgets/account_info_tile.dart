import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';

class AccountInfoTile extends StatelessWidget {
  const AccountInfoTile({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.caption),
          ),
          if (value.isNotEmpty)
            Flexible(
              child: Text(
                value,
                style: AppTextStyles.bodyStrong,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}
