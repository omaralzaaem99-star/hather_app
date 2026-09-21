import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/constants/app_info.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/features/account/presentation/widgets/account_widgets.dart';
import 'package:hather_app/features/account/presentation/widgets/captain_subscription_accordion_body.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Shared account section cards for user and captain screens.
class AccountScreenSections {
  const AccountScreenSections._();

  static AccountAccordionSection settings({
    required AppLocalizations l10n,
    required List<Widget> rows,
    bool initiallyExpanded = false,
  }) {
    return AccountAccordionSection(
      title: l10n.accountSectionSettings,
      initiallyExpanded: initiallyExpanded,
      rows: rows,
    );
  }

  static AccountAccordionSection privacySecurity({
    required AppLocalizations l10n,
    required VoidCallback onDeleteAccount,
    required BuildContext context,
  }) {
    return AccountAccordionSection(
      title: l10n.accountSectionPrivacySecurity,
      rows: [
        AccountSettingsRow(
          label: l10n.accountPrivacyPolicy,
          onTap: () => context.push(AuthenticatedRoutes.privacyPolicy),
        ),
        AccountSettingsRow(
          label: l10n.accountTerms,
          onTap: () => context.push(AuthenticatedRoutes.terms),
        ),
        AccountSettingsRow(
          label: l10n.accountDeleteAccount,
          textColor: AppColors.error,
          onTap: onDeleteAccount,
          showDivider: false,
        ),
      ],
    );
  }

  static AccountAccordionSection appInfo({
    required AppLocalizations l10n,
    required BuildContext context,
  }) {
    return AccountAccordionSection(
      title: l10n.accountSectionAppInfo,
      rows: [
        AccountSettingsRow(
          label: l10n.accountAbout,
          onTap: () => context.push(AuthenticatedRoutes.about),
        ),
        AccountSettingsRow(
          label: l10n.accountAppVersion,
          trailing: Text(
            AppInfo.version,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            textDirection: TextDirection.ltr,
          ),
          showDivider: false,
        ),
      ],
    );
  }

  static AccountAccordionSection technicalSupport({
    required AppLocalizations l10n,
    required BuildContext context,
  }) {
    return AccountAccordionSection(
      title: l10n.accountSectionTechnicalSupport,
      expandedBody: TechnicalSupportAccordionBody(
        onOpenSupport: () => context.push(AuthenticatedRoutes.support),
      ),
    );
  }

  static AccountAccordionSection captainSubscription({
    required AppLocalizations l10n,
    required Widget body,
  }) {
    return AccountAccordionSection(
      title: l10n.captainSubscriptionTitle,
      initiallyExpanded: true,
      expandedBody: body,
    );
  }
}
