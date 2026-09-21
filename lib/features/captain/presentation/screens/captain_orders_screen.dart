import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/captain/presentation/providers/captain_order_providers.dart';
import 'package:hather_app/features/captain/presentation/widgets/available_order_card.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Captain "طلباتي": tabs for active vs completed only.
class CaptainOrdersScreen extends ConsumerStatefulWidget {
  const CaptainOrdersScreen({super.key});

  @override
  ConsumerState<CaptainOrdersScreen> createState() =>
      _CaptainOrdersScreenState();
}

class _CaptainOrdersScreenState extends ConsumerState<CaptainOrdersScreen> {
  /// 0 = تحت التنفيذ, 1 = المكتملة
  int _tabIndex = 0;

  String _statusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'active' => l10n.captainOrderStatusActive,
      'completed' => l10n.orderStatusCompleted,
      'cancelled' => l10n.orderStatusCancelled,
      'expired' => l10n.orderStatusExpired,
      'pending' => l10n.captainOrderAvailableBadge,
      _ => l10n.orderStatusUnknown,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'active' => AppColors.icon,
      'completed' => AppColors.success,
      _ => AppColors.textSecondary,
    };
  }

  void _openOrder(BuildContext context, String orderId) {
    context.push(AuthenticatedRoutes.captainAvailableOrderPath(orderId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(captainMyOrdersProvider);

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
                  Text(
                    l10n.captainMyOrdersSubtitle,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ordersAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.icon),
                ),
                error: (_, _) => _TabEmpty(
                  message: l10n.captainOrdersEmpty,
                  hint: l10n.captainMyOrdersEmptyHint,
                ),
                data: (orders) {
                  final active = orders
                      .where((o) => o.status == 'active')
                      .toList();
                  final completed = orders
                      .where((o) => o.status == 'completed')
                      .toList();
                  final list = _tabIndex == 0 ? active : completed;
                  final emptyMessage = _tabIndex == 0
                      ? l10n.captainOrdersEmptyUnderExecution
                      : l10n.captainOrdersEmptyCompletedTab;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                        child: _CaptainOrdersTabs(
                          selectedIndex: _tabIndex,
                          activeLabel:
                              '🚚 ${l10n.captainOrdersTabUnderExecution} (${active.length})',
                          completedLabel:
                              '✅ ${l10n.captainOrdersTabCompleted} (${completed.length})',
                          onChanged: (i) => setState(() => _tabIndex = i),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.icon,
                          onRefresh: () async {
                            refreshCaptainOrders(ref);
                            await ref.read(captainMyOrdersProvider.future);
                          },
                          child: list.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    48,
                                    28,
                                    110,
                                  ),
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 52,
                                      color: AppColors.textMuted
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      emptyMessage,
                                      style: AppTextStyles.bodyStrong,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    110,
                                  ),
                                  itemCount: list.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final order = list[index];
                                    return CaptainMyOrderCard(
                                      order: order,
                                      statusLabel:
                                          _statusLabel(l10n, order.status),
                                      statusColor:
                                          _statusColor(order.status),
                                      onTap: () =>
                                          _openOrder(context, order.id),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
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

class _CaptainOrdersTabs extends StatelessWidget {
  const _CaptainOrdersTabs({
    required this.selectedIndex,
    required this.activeLabel,
    required this.completedLabel,
    required this.onChanged,
  });

  final int selectedIndex;
  final String activeLabel;
  final String completedLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: activeLabel,
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabChip(
              label: completedLabel,
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.85)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabEmpty extends StatelessWidget {
  const _TabEmpty({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              message,
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
      ),
    );
  }
}
