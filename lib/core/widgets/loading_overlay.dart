import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    required this.isLoading,
    required this.child,
    super.key,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.overlay,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
