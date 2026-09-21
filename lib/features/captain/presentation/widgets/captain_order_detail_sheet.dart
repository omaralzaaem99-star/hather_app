import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/core/utils/iqd_format.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:hather_app/features/captain/presentation/providers/captain_order_providers.dart';
import 'package:hather_app/features/delivery/presentation/utils/delivery_request_number.dart';
import 'package:hather_app/features/delivery/presentation/utils/order_remaining_time.dart';
import 'package:hather_app/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

Future<void> showCaptainAvailableOrderSheet(
  BuildContext context,
  WidgetRef ref,
  CaptainAvailableOrder order,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CaptainAvailableOrderSheet(order: order),
  );
}

Future<void> showCaptainMyOrderDetailSheet(
  BuildContext context,
  WidgetRef ref,
  CaptainMyOrder order,
) async {
  final repo = ref.read(captainOrderRepositoryProvider);
  final result = await repo.getMyOrderDetail(order.id);
  if (!context.mounted) return;
  result.when(
    success: (detail) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _CaptainMyOrderDetailSheet(detail: detail),
      );
    },
    onFailure: (failure) {
      final message = failure is Failure
          ? mapFailureToMessage(context, failure)
          : AppLocalizations.of(context).errorUnknown;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    },
  );
}

class _CaptainAvailableOrderSheet extends ConsumerStatefulWidget {
  const _CaptainAvailableOrderSheet({required this.order});

  final CaptainAvailableOrder order;

  @override
  ConsumerState<_CaptainAvailableOrderSheet> createState() =>
      _CaptainAvailableOrderSheetState();
}

class _CaptainAvailableOrderSheetState
    extends ConsumerState<_CaptainAvailableOrderSheet> {
  bool _accepting = false;

  Future<void> _accept() async {
    if (_accepting) return;
    final l10n = AppLocalizations.of(context);
    if (OrderRemainingTime.isExpired(widget.order.expiresAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainOrderExpiredLabel)),
      );
      return;
    }
    final subscription = ref.read(myCaptainSubscriptionProvider).value;
    if (subscription == null || !subscription.hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainSubscriptionRequiredAccept)),
      );
      return;
    }

    setState(() => _accepting = true);
    final result = await ref
        .read(captainOrderRepositoryProvider)
        .acceptOrder(widget.order.id);
    if (!mounted) return;
    setState(() => _accepting = false);

    result.when(
      success: (detail) {
        refreshCaptainOrders(ref);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.captainAcceptOrderSuccess)),
        );
        context.go(AuthenticatedRoutes.captainOrders);
      },
      onFailure: (failure) {
        final message = failure is Failure
            ? mapFailureToMessage(context, failure)
            : l10n.errorUnknown;
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        if (message.contains('كابتن آخر') ||
            message.contains('انتهت صلاحية') ||
            message.contains('الحد الأقصى من الطلبات قيد التنفيذ')) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subscriptionAsync = ref.watch(myCaptainSubscriptionProvider);
    final hasSubscription = subscriptionAsync.maybeWhen(
      data: (info) => info.hasActiveSubscription,
      orElse: () => false,
    );
    final expired = OrderRemainingTime.isExpired(widget.order.expiresAt);
    final canAccept = hasSubscription && !expired && !_accepting;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.captainViewOrderDetails,
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 16),
          if (widget.order.requestNumber != null)
            _OrderNumberCopyRow(requestNumber: widget.order.requestNumber!),
          if (widget.order.requestNumber != null) const SizedBox(height: 8),
          _PreviewRow(
            label: l10n.captainOrderTypeLabel,
            value: l10n.deliveryOrderDisplayTitle,
          ),
          _PreviewRow(label: l10n.captainOrderDetailsLabel, value: widget.order.details),
          _PreviewRow(
            label: l10n.captainOrderDestinationLabel,
            value: widget.order.destinationLabel,
          ),
          _PreviewRow(
            label: l10n.captainOrderFeeLabel(
              IqdFormat.format(widget.order.deliveryFeeIqd),
            ),
            value: '',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.captainOrderRemainingTimeLabel,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 4),
                OrderRemainingTimeText(
                  expiresAt: widget.order.expiresAt,
                  compact: false,
                  builder: (context, label, isExpired) => Text(
                    isExpired ? label : '⏱ $label',
                    style: AppTextStyles.body.copyWith(
                      color:
                          isExpired ? AppColors.error : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!hasSubscription) ...[
            const SizedBox(height: 12),
            Text(
              l10n.captainSubscriptionRequiredAccept,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: l10n.captainAcceptOrderAction,
            isLoading: _accepting,
            enabled: canAccept,
            onPressed: canAccept ? _accept : null,
          ),
        ],
      ),
    );
  }
}

class _CaptainMyOrderDetailSheet extends ConsumerStatefulWidget {
  const _CaptainMyOrderDetailSheet({required this.detail});

  final CaptainOrderDetail detail;

  @override
  ConsumerState<_CaptainMyOrderDetailSheet> createState() =>
      _CaptainMyOrderDetailSheetState();
}

class _CaptainMyOrderDetailSheetState
    extends ConsumerState<_CaptainMyOrderDetailSheet> {
  late CaptainOrderDetail _detail;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
  }

  Future<void> _completeOrder() async {
    if (_completing || !_detail.isActive) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _completing = true);
    final result = await ref
        .read(captainOrderRepositoryProvider)
        .completeOrder(_detail.id);
    if (!mounted) return;
    setState(() => _completing = false);

    result.when(
      success: (detail) {
        setState(() => _detail = detail);
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.captainCompleteOrderSuccess)),
        );
      },
      onFailure: (failure) {
        final message = failure is Failure
            ? mapFailureToMessage(context, failure)
            : l10n.errorUnknown;
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = _detail.customerPhone == null
        ? '—'
        : (PhoneNumberFormatter.toLocalDisplay(_detail.customerPhone!) ??
            _detail.customerPhone!);
    final completedAt = _detail.completedAt;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.deliveryOrderDisplayTitle, style: AppTextStyles.sectionTitle),
          if (_detail.requestNumber != null) ...[
            const SizedBox(height: 12),
            _OrderNumberCopyRow(requestNumber: _detail.requestNumber!),
          ],
          const SizedBox(height: 12),
          _PreviewRow(label: l10n.captainOrderDetailsLabel, value: _detail.details),
          _PreviewRow(
            label: l10n.captainOrderDestinationLabel,
            value: _detail.destinationAddress ?? _detail.destinationLabel,
          ),
          if (_detail.destinationLat != null &&
              _detail.destinationLng != null)
            _PreviewRow(
              label: l10n.captainOrderGpsLabel,
              value:
                  '${_detail.destinationLat!.toStringAsFixed(5)}, ${_detail.destinationLng!.toStringAsFixed(5)}',
            ),
          _PreviewRow(
            label: l10n.fullName,
            value: (_detail.customerName?.trim().isNotEmpty ?? false)
                ? _detail.customerName!.trim()
                : l10n.valueNotAvailable,
          ),
          _PreviewRow(label: l10n.phoneNumber, value: phone),
          _PreviewRow(
            label: l10n.captainOrderFeeLabel(
              IqdFormat.format(_detail.deliveryFeeIqd),
            ),
            value: '',
          ),
          if (_detail.isCompleted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.captainOrderCompletedBadge,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            if (completedAt != null) ...[
              const SizedBox(height: 8),
              _PreviewRow(
                label: l10n.captainOrderCompletedAtLabel,
                value: AppDateTimeFormat.dateTime(completedAt),
              ),
            ],
          ],
          if (_detail.isActive) ...[
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.captainCompleteOrderAction,
              isLoading: _completing,
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.onPrimary,
              onPressed: _completing ? null : _completeOrder,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderNumberCopyRow extends StatelessWidget {
  const _OrderNumberCopyRow({required this.requestNumber});

  final int requestNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          if (value.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }
}
