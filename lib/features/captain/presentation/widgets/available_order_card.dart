import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/core/utils/iqd_format.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:hather_app/features/delivery/presentation/utils/delivery_request_number.dart';
import 'package:hather_app/features/delivery/presentation/utils/order_remaining_time.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Compact available-order preview on Captain Home (tap → detail, no Accept).
class AvailableOrderCard extends StatelessWidget {
  const AvailableOrderCard({
    required this.order,
    required this.onTap,
    super.key,
  });

  final CaptainAvailableOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requestAccent = Theme.of(context).brightness == Brightness.light
        ? AppColors.primary
        : AppColors.icon;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DeliveryRequestNumber.display(order.requestNumber),
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: requestAccent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pendingOrder.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.pendingOrder.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      l10n.captainOrderAvailableBadge,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.pendingOrder,
                        fontWeight: FontWeight.w700,
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    l10n.captainOrderFeeLabel(
                      IqdFormat.format(order.deliveryFeeIqd),
                    ),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  OrderRemainingTimeText(
                    expiresAt: order.expiresAt,
                    builder: (context, label, expired) {
                      return Text(
                        expired ? label : '⏱ $label',
                        style: AppTextStyles.caption.copyWith(
                          color:
                              expired ? AppColors.error : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CaptainMyOrderCard extends StatelessWidget {
  const CaptainMyOrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    this.onTap,
    super.key,
  });

  final CaptainMyOrder order;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = order.isCompleted && order.completedAt != null
        ? AppDateTimeFormat.dateTime(order.completedAt!)
        : AppDateTimeFormat.dateTime(order.acceptedAt ?? order.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.deliveryOrderDisplayTitle,
                      style: AppTextStyles.bodyStrong,
                    ),
                  ),
                  Text(
                    DeliveryRequestNumber.display(order.requestNumber),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.icon,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.details,
                      style: AppTextStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.destinationLabel,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 10),
              Text(date, style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}
