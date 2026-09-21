import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/features/subscription/domain/entities/captain_subscription_info.dart';
import 'package:hather_app/l10n/app_localizations.dart';

String captainSubscriptionSummary(
  AppLocalizations l10n,
  CaptainSubscriptionInfo info,
) {
  if (!info.hasActiveSubscription) {
    if (info.status == CaptainSubscriptionStatus.expired) {
      return l10n.captainSubscriptionExpired;
    }
    return l10n.captainSubscriptionNone;
  }
  return switch (info.subscriptionType) {
    CaptainSubscriptionType.trial => l10n.captainSubscriptionActiveTrial,
    CaptainSubscriptionType.paid => l10n.captainSubscriptionActivePaid,
    CaptainSubscriptionType.none => l10n.captainSubscriptionNone,
  };
}

String formatCaptainDateTime(DateTime utc) => AppDateTimeFormat.dateTime(utc);

class CaptainSubscriptionCard extends StatelessWidget {
  const CaptainSubscriptionCard({
    required this.info,
    super.key,
  });

  final CaptainSubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = captainSubscriptionSummary(l10n, info);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              Icon(
                Icons.card_membership_rounded,
                color: AppColors.icon.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.captainSubscriptionTitle,
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(summary, style: AppTextStyles.bodyStrong),
          if (info.hasActiveSubscription) ...[
            const SizedBox(height: 8),
            Text(
              l10n.captainSubscriptionRemaining(info.remainingDays.toString()),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (info.endsAt != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.captainSubscriptionEndsAt(
                formatCaptainDateTime(info.endsAt!),
              ),
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class CaptainInfoTile extends StatelessWidget {
  const CaptainInfoTile({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.caption),
          ),
          if (value.isNotEmpty)
            Text(value, style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}
