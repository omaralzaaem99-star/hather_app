import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/account/presentation/widgets/account_widgets.dart';
import 'package:hather_app/features/captain/presentation/widgets/captain_subscription_card.dart';
import 'package:hather_app/features/subscription/domain/entities/captain_subscription_info.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Subscription details inside the captain account card.
class CaptainSubscriptionAccordionBody extends StatelessWidget {
  const CaptainSubscriptionAccordionBody({
    required this.info,
    super.key,
  });

  final CaptainSubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!info.hasActiveSubscription &&
        info.status != CaptainSubscriptionStatus.expired) {
      return _Shell(
        child: Text(
          l10n.captainSubscriptionNone,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    if (info.status == CaptainSubscriptionStatus.expired) {
      return _Shell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AccountStatusBadge(
                label: l10n.subscriptionStatusExpired,
                tone: AccountBadgeTone.expired,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.captainSubscriptionExpired,
              style: AppTextStyles.bodyStrong,
            ),
          ],
        ),
      );
    }

    final typeLabel = switch (info.subscriptionType) {
      CaptainSubscriptionType.trial => l10n.subscriptionTrialLabel,
      CaptainSubscriptionType.paid => l10n.subscriptionPaidLabel,
      CaptainSubscriptionType.none => l10n.captainSubscriptionNone,
    };

    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(typeLabel, style: AppTextStyles.bodyStrong),
              ),
              AccountStatusBadge(
                label: l10n.subscriptionStatusActive,
                tone: AccountBadgeTone.active,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text: l10n.captainSubscriptionRemaining(
              info.remainingDays.toString(),
            ),
          ),
          if (info.endsAt != null) ...[
            const SizedBox(height: 8),
            _DetailLine(
              icon: Icons.event_rounded,
              text: l10n.subscriptionEndsLabel(
                formatCaptainDateTime(info.endsAt!),
              ),
              ltr: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: child,
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.text,
    this.ltr = false,
  });

  final IconData icon;
  final String text;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.icon.withValues(alpha: 0.85)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textDirection: ltr ? TextDirection.ltr : null,
          ),
        ),
      ],
    );
  }
}

/// Placeholder body for technical support — ready for admin panel data later.
class TechnicalSupportAccordionBody extends StatelessWidget {
  const TechnicalSupportAccordionBody({
    required this.onOpenSupport,
    super.key,
  });

  final VoidCallback onOpenSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountSettingsRow(
          label: l10n.accountSupport,
          onTap: onOpenSupport,
          showDivider: false,
        ),
      ],
    );
  }
}
