import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/widgets/home_ads_carousel.dart';
import 'package:hather_app/core/widgets/home_screen_header.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/captain/presentation/providers/captain_order_providers.dart';
import 'package:hather_app/features/captain/presentation/widgets/available_order_card.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:hather_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:hather_app/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class CaptainHomeScreen extends ConsumerStatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  ConsumerState<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends ConsumerState<CaptainHomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      refreshCaptainOrders(ref);
      ref.invalidate(myCaptainSubscriptionProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshCaptainOrders(ref);
      ref.invalidate(myCaptainSubscriptionProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

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
    final availableOrdersAsync = ref.watch(captainAvailableOrdersProvider);
    final capacityAsync = ref.watch(captainActiveOrderCapacityProvider);
    final subscriptionAsync = ref.watch(myCaptainSubscriptionProvider);
    final hasActiveSubscription = subscriptionAsync.maybeWhen(
      data: (info) => info.hasActiveSubscription,
      orElse: () => true, // don't flash subscription empty while loading
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.icon,
          onRefresh: () async {
            ref.invalidate(myCaptainSubscriptionProvider);
            refreshCaptainOrders(ref);
            await Future.wait([
              ref.read(myCaptainSubscriptionProvider.future),
              ref.read(captainAvailableOrdersProvider.future),
              ref.read(captainActiveOrderCapacityProvider.future),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: HomeScreenHeader(
                  welcomeName: (user?.fullName.trim().isNotEmpty ?? false)
                      ? user!.fullName.trim()
                      : l10n.valueNotAvailable,
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
                        l10n.captainAvailableOrdersTitle,
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.captainAvailableOrdersSubtitle,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              if (!hasActiveSubscription)
                SliverToBoxAdapter(
                  child: _AvailableOrdersEmpty(
                    title: l10n.captainSubscriptionNone,
                    hint: l10n.captainSubscriptionRequiredAccept,
                  ),
                )
              else
                availableOrdersAsync.when(
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.icon),
                      ),
                    ),
                  ),
                  error: (_, _) => SliverToBoxAdapter(
                    child: _AvailableOrdersEmpty(
                      title: l10n.captainAvailableOrdersLoadError,
                      hint: l10n.retryAction,
                    ),
                  ),
                  data: (orders) {
                    final atCapacity = capacityAsync.maybeWhen(
                      data: (capacity) => capacity.atCapacity,
                      orElse: () => false,
                    );

                    if (atCapacity) {
                      return SliverToBoxAdapter(
                        child: _AvailableOrdersEmpty(
                          title: l10n.captainActiveOrdersAtCapacityTitle,
                          hint: l10n.captainActiveOrdersAtCapacityHint,
                        ),
                      );
                    }

                    if (orders.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _AvailableOrdersEmpty(
                          title: l10n.captainAvailableOrdersEmpty,
                          hint: l10n.captainAvailableOrdersEmptyHint,
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return AvailableOrderCard(
                            order: order,
                            onTap: () => context.push(
                              AuthenticatedRoutes.captainAvailableOrderPath(
                                order.id,
                              ),
                              extra: order,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableOrdersEmpty extends StatelessWidget {
  const _AvailableOrdersEmpty({
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
      child: Column(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 52,
            color: AppColors.textMuted.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.bodyStrong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
