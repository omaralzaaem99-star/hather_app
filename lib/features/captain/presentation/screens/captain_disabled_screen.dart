import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/widgets/account_restricted_actions.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class CaptainDisabledScreen extends ConsumerWidget {
  const CaptainDisabledScreen({super.key});

  Future<void> _signOut(WidgetRef ref, BuildContext context) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Icon(
                  Icons.block_rounded,
                  size: 72,
                  color: AppColors.error.withValues(alpha: 0.85),
                ),
                const SizedBox(height: AppDimensions.spaceXl),
                Text(
                  l10n.captainDisabledTitle,
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 24,
                    shadows: const [],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                Text(
                  l10n.captainDisabledMessage,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                PrimaryButton(
                  label: l10n.accountBlockedContactAdmin,
                  onPressed: () => contactAdminSupport(
                    context: context,
                    ref: ref,
                    onLaunchFailed: () {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.supportLaunchFailed)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                TextButton(
                  onPressed: () => _signOut(ref, context),
                  child: Text(
                    l10n.signOut,
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
