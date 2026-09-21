import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:hather_app/features/delivery/presentation/utils/delivery_request_number.dart';
import 'package:hather_app/features/delivery/presentation/utils/user_orders_sort.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// User "طلباتي": single list sorted by status priority, then newest first.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  String _statusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'pending' => l10n.orderStatusPending,
      'active' => l10n.orderStatusActive,
      'completed' => l10n.orderStatusCompleted,
      'cancelled' => l10n.orderStatusCancelled,
      'expired' => l10n.orderStatusExpired,
      _ => l10n.orderStatusUnknown,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'pending' => AppColors.pendingOrder,
      'active' => AppColors.icon,
      'completed' => AppColors.success,
      'cancelled' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  /// Defensive filter + sort (repository already sorts; keep for safety).
  List<DeliveryOrder> _sortedVisible(List<DeliveryOrder> orders) {
    return sortUserDeliveryOrders(orders);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ordersTitle,
                    style: AppTextStyles.screenTitle.copyWith(
                      fontSize: 26,
                      shadows: const [],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.ordersSubtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Expanded(
              child: ordersAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.icon),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(l10n.ordersLoadError, style: AppTextStyles.body),
                ),
                data: (orders) {
                  final visible = _sortedVisible(orders);
                  return RefreshIndicator(
                    color: AppColors.icon,
                    onRefresh: () async {
                      ref.invalidate(myOrdersProvider);
                      await ref.read(myOrdersProvider.future);
                    },
                    child: visible.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(28, 48, 28, 110),
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 52,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                l10n.ordersEmptyNow,
                                style: AppTextStyles.bodyStrong,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final order = visible[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OrderCard(
                                  order: order,
                                  statusLabel:
                                      _statusLabel(l10n, order.status),
                                  statusColor: _statusColor(order.status),
                                  onTap: () => context.push(
                                    '/delivery/orders/${order.id}',
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final DeliveryOrder order;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = AppDateTimeFormat.dateTime(order.createdAt);
    final isPending = order.isPending;
    final cardBorder = isPending
        ? AppColors.pendingOrder.withValues(alpha: 0.85)
        : AppColors.borderSubtle;
    final badgeBg = isPending
        ? AppColors.pendingOrder.withValues(alpha: 0.14)
        : statusColor.withValues(alpha: 0.16);
    final badgeBorder = isPending
        ? AppColors.pendingOrder.withValues(alpha: 0.75)
        : statusColor.withValues(alpha: 0.4);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: cardBorder,
              width: isPending ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.requestNumber != null
                          ? DeliveryRequestNumber.display(order.requestNumber!)
                          : order.orderTypeName.isEmpty
                              ? 'طلب توصيل'
                              : order.orderTypeName,
                      style: AppTextStyles.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.details,
                style: AppTextStyles.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(date, style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}
