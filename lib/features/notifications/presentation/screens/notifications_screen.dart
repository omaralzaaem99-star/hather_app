import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/notifications/notification_navigation.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';
import 'package:hather_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:hather_app/features/notifications/presentation/utils/notification_time_format.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      ref.read(notificationsListControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _onOpen(UserNotification notification) async {
    await NotificationNavigation.handleNotification(
      context: context,
      ref: ref,
      notification: notification,
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'delivery_order_available' => Icons.delivery_dining_outlined,
      'delivery_order_assigned' => Icons.assignment_ind_outlined,
      'delivery_order_released' => Icons.swap_horiz_outlined,
      'delivery_order_cancelled' => Icons.cancel_outlined,
      'delivery_order_expired' => Icons.timer_off_outlined,
      'delivery_order_accepted' => Icons.local_shipping_outlined,
      'delivery_order_completed' => Icons.check_circle_outline,
      'delivery_order_searching_captain' => Icons.search_outlined,
      'support_reply' => Icons.support_agent_outlined,
      'captain_approved' => Icons.verified_outlined,
      'captain_rejected' => Icons.info_outline,
      'captain_suspended' => Icons.pause_circle_outline,
      'captain_disabled' => Icons.block_outlined,
      'account_reactivated' => Icons.check_circle_outline,
      'subscription_activated' => Icons.card_membership_outlined,
      'admin_broadcast' => Icons.campaign_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(notificationsListControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l10n.notificationsTitle, style: AppTextStyles.screenTitle),
        actions: [
          if (state.hasUnread)
            TextButton(
              onPressed: () => ref
                  .read(notificationsListControllerProvider.notifier)
                  .markAllRead(),
              child: Text(
                l10n.notificationsMarkAllRead,
                style: AppTextStyles.caption.copyWith(color: AppColors.icon),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.icon,
        onRefresh: () =>
            ref.read(notificationsListControllerProvider.notifier).refresh(),
        child: _buildBody(l10n, state),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, NotificationsListState state) {
    if (state.isLoading && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(color: AppColors.icon)),
        ],
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
        children: [
          Text(
            state.errorMessage!,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => ref
                  .read(notificationsListControllerProvider.notifier)
                  .refresh(),
              child: Text(l10n.retryAction, style: AppTextStyles.link),
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 52,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.notificationsEmpty,
            style: AppTextStyles.bodyStrong,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.icon,
                ),
              ),
            ),
          );
        }
        final item = state.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _NotificationCard(
            notification: item,
            icon: _iconFor(item.type),
            timeLabel: NotificationTimeFormat.relative(item.createdAt),
            onTap: () => _onOpen(item),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.timeLabel,
    required this.onTap,
  });

  final UserNotification notification;
  final IconData icon;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final borderColor = unread
        ? AppColors.icon.withValues(alpha: 0.55)
        : AppColors.borderSubtle;
    final bg = unread
        ? AppColors.icon.withValues(alpha: 0.08)
        : AppColors.surface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: borderColor,
              width: unread ? 1.3 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyStrong.copyWith(
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.icon,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body, style: AppTextStyles.body),
                    const SizedBox(height: 8),
                    Text(timeLabel, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
