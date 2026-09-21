import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/routing/safe_navigation.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/core/utils/iqd_format.dart';
import 'package:hather_app/core/widgets/error_message.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:hather_app/features/delivery/presentation/utils/delivery_request_number.dart';
import 'package:hather_app/features/delivery/presentation/widgets/order_captain_contact_section.dart';
import 'package:hather_app/features/delivery/presentation/widgets/order_progress_tracker.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class UserOrderDetailScreen extends ConsumerStatefulWidget {
  const UserOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<UserOrderDetailScreen> createState() =>
      _UserOrderDetailScreenState();
}

class _UserOrderDetailScreenState extends ConsumerState<UserOrderDetailScreen> {
  bool _cancelling = false;
  String? _actionError;

  void _handleBack() {
    safeBack(context, fallbackLocation: '/orders');
  }

  Future<void> _confirmCancel(DeliveryOrder order) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.cancelOrderTitle, style: AppTextStyles.bodyStrong),
        content: Text(l10n.cancelOrderConfirmBody, style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelOrderBack),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.cancelOrderConfirmAction,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
      _actionError = null;
    });
    final result =
        await ref.read(deliveryRepositoryProvider).cancelOrder(order.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        setState(() => _cancelling = false);
        ref.invalidate(orderDetailProvider(widget.orderId));
        ref.invalidate(myOrdersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.orderCancelledSuccess)),
        );
      },
      onFailure: (error) {
        setState(() {
          _cancelling = false;
          _actionError = error is Failure
              ? mapFailureToMessage(context, error)
              : l10n.errorUnknown;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(orderDetailProvider(widget.orderId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(l10n.orderDetailTitle, style: AppTextStyles.bodyStrong),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(l10n.ordersLoadError, style: AppTextStyles.body),
          ),
          data: (order) {
            if (order == null) {
              return Center(
                child: Text(l10n.ordersLoadError, style: AppTextStyles.body),
              );
            }
            final date = AppDateTimeFormat.dateTime(order.createdAt);
            final deliveredAt = order.completedAt == null
                ? null
                : AppDateTimeFormat.dateTime(order.completedAt!);
            final expiredAt = order.expiresAt == null
                ? null
                : AppDateTimeFormat.dateTime(order.expiresAt!);
            return RefreshIndicator(
              color: AppColors.icon,
              onRefresh: () async {
                ref.invalidate(orderDetailProvider(widget.orderId));
                await ref.read(orderDetailProvider(widget.orderId).future);
              },
              child: ListView(
                padding: AppDimensions.scrollPadding(context, bottom: 40),
                children: [
                  AuthFormErrorBanner(message: _actionError),
                  OrderProgressTracker(status: order.status),
                  if (order.requestNumber != null) ...[
                    const SizedBox(height: 14),
                    _OrderNumberRow(requestNumber: order.requestNumber!),
                  ],
                  const SizedBox(height: 16),
                  _OrderDetailsCard(
                    label: l10n.orderDetailsLabel,
                    details: order.details,
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: l10n.destinationLabel,
                    child: Text(
                      order.destinationLabel ??
                          order.destinationAddress ??
                          l10n.locationConfirmed,
                      style: AppTextStyles.body,
                    ),
                  ),
                  if (order.deliveryFeeIqd != null) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: l10n.deliveryFeeLabel,
                      child: Text(
                        '${IqdFormat.format(order.deliveryFeeIqd!)} د.ع',
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _Section(
                    title: l10n.orderCreatedAtLabel,
                    child: Text(date, style: AppTextStyles.body),
                  ),
                  if (order.isExpired && expiredAt != null) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: l10n.orderExpiresAtLabel,
                      child: Text(expiredAt, style: AppTextStyles.body),
                    ),
                  ],
                  if (order.isCompleted && deliveredAt != null) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: l10n.orderDeliveredAtLabel,
                      child: Text(deliveredAt, style: AppTextStyles.body),
                    ),
                  ],
                  if (order.isPending &&
                      order.captainName == null &&
                      order.captainPhone == null) ...[
                    const SizedBox(height: 16),
                    _Section(
                      title: l10n.orderCaptainSectionTitle,
                      child: Text(
                        l10n.orderWaitingCaptainHint,
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                  if ((order.isActive || order.isCompleted) &&
                      (order.captainName != null ||
                          order.captainPhone != null)) ...[
                    const SizedBox(height: 16),
                    _Section(
                      title: l10n.orderCaptainSectionTitle,
                      child: OrderCaptainContactSection(
                        captainName: order.captainName,
                        captainPhone: order.captainPhone,
                      ),
                    ),
                  ],
                  if (order.isPending) ...[
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: l10n.cancelOrderAction,
                      isLoading: _cancelling,
                      onPressed:
                          _cancelling ? null : () => _confirmCancel(order),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderNumberRow extends StatelessWidget {
  const _OrderNumberRow({required this.requestNumber});

  final int requestNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.orderNumberLabel, style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(
                  DeliveryRequestNumber.display(requestNumber),
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.icon,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () =>
                DeliveryRequestNumber.copyToClipboard(context, requestNumber),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l10n.copyOrderNumberAction),
            style: TextButton.styleFrom(foregroundColor: AppColors.icon),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({
    required this.label,
    required this.details,
  });

  final String label;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppColors.icon.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.icon,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            details,
            softWrap: true,
            textAlign: TextAlign.start,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 18,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.caption),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
