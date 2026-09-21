import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/constants/home_assets.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/widgets/home_ads_carousel.dart';
import 'package:hather_app/core/widgets/home_screen_header.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:hather_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _openNotifications() {
    context.push('/notifications');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).user;
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadAsync.maybeWhen(
      data: (value) => value,
      orElse: () => 0,
    );
    final adsAsync = ref.watch(homeAdsProvider);
    final ads = adsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <HomeAd>[],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: HomeScreenHeader(
                welcomeName: user?.fullName ?? '',
                onNotificationsPressed: _openNotifications,
                unreadCount: unreadCount,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(child: HomeAdsCarousel(ads: ads)),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.servicesSectionTitle,
                      style: AppTextStyles.bodyStrong,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.servicesSectionSubtitle,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    _ServiceBannerCard(
                      imageAsset: HomeAssets.deliveryBanner,
                      ctaLabel: l10n.deliveryServiceCta,
                      onTap: () => context.push('/delivery/create-order'),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceBannerCard extends StatelessWidget {
  const _ServiceBannerCard({
    required this.imageAsset,
    required this.onTap,
    this.ctaLabel,
  });

  final String imageAsset;
  final VoidCallback onTap;
  final String? ctaLabel;

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final borderRadius = BorderRadius.circular(_radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: isLight
              ? AppColors.border.withValues(alpha: 0.55)
              : AppColors.borderSubtle,
          width: 1,
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 16 / 7.2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Container(
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                  if (ctaLabel != null)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              ctaLabel!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.onPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
