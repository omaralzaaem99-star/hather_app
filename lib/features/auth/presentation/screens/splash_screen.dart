import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/widgets/auth_header.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_hero_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(authControllerProvider.notifier).restoreSession();
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.isAuthenticated) {
      final user = auth.user;
      if (kDebugMode && user != null) {
        debugPrint(
          'SPLASH: authenticated type=${user.accountType.name} '
          'status=${user.accountStatus.name} '
          'route=${AuthenticatedRoutes.homeFor(user)}',
        );
      }
      context.go(AuthenticatedRoutes.homeFor(auth.user));
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthHeroBackground(),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 100),
                  const SizedBox(height: AppDimensions.spaceXl),
                  const CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
