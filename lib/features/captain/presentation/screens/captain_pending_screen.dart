import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class CaptainPendingScreen extends ConsumerStatefulWidget {
  const CaptainPendingScreen({super.key});

  @override
  ConsumerState<CaptainPendingScreen> createState() =>
      _CaptainPendingScreenState();
}

class _CaptainPendingScreenState extends ConsumerState<CaptainPendingScreen>
    with WidgetsBindingObserver {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfile();
    }
  }

  Future<void> _refreshProfile() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await ref.read(authControllerProvider.notifier).refreshProfile();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen(authControllerProvider, (previous, next) {
      if (!mounted) return;
      final prevZone = AuthenticatedRoutes.zoneFor(previous?.user);
      final nextZone = AuthenticatedRoutes.zoneFor(next.user);
      if (prevZone != AccountRouteZone.captainPending) return;
      if (nextZone == AccountRouteZone.captainPending) return;

      if (kDebugMode) {
        debugPrint('CAPTAIN PENDING: auth zone changed');
        debugPrint('CAPTAIN PENDING: leaving pending screen');
      }
      context.go(AuthenticatedRoutes.homeFor(next.user));
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.hourglass_top_rounded,
                size: 72,
                color: AppColors.icon.withValues(alpha: 0.9),
              ),
              const SizedBox(height: AppDimensions.spaceXl),
              Text(
                l10n.captainPendingScreenTitle,
                style: AppTextStyles.screenTitle.copyWith(
                  fontSize: 24,
                  shadows: const [],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                l10n.captainPendingScreenMessage,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                l10n.captainPendingScreenHint,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              PrimaryButton(
                label: l10n.captainPendingRefreshStatus,
                isLoading: _refreshing,
                onPressed: _refreshProfile,
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              TextButton(
                onPressed: _refreshing ? null : _signOut,
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
    );
  }
}
