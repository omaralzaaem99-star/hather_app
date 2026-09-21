import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/account/presentation/widgets/account_page_layout.dart';
import 'package:hather_app/features/account/presentation/widgets/account_screen_sections.dart';
import 'package:hather_app/features/account/presentation/widgets/account_theme_setting_row.dart';
import 'package:hather_app/features/account/presentation/widgets/account_widgets.dart';
import 'package:hather_app/features/account/presentation/widgets/captain_subscription_accordion_body.dart';
import 'package:hather_app/features/account/presentation/widgets/delete_account_flow.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/subscription/domain/entities/captain_subscription_info.dart';
import 'package:hather_app/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class CaptainAccountScreen extends ConsumerWidget {
  const CaptainAccountScreen({super.key});

  Future<void> _onDeleteAccount(
    BuildContext context,
    WidgetRef ref, {
    required bool warnActiveSubscription,
  }) async {
    await showDeleteAccountFlow(
      context,
      ref: ref,
      warnActiveSubscription: warnActiveSubscription,
    );
  }

  Future<void> _signOut(WidgetRef ref, BuildContext context) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).user;
    final phoneDisplay = user == null
        ? '—'
        : (PhoneNumberFormatter.toLocalDisplay(user.phone) ?? user.phone);
    final subscriptionAsync = ref.watch(myCaptainSubscriptionProvider);

    final subscriptionInfo = subscriptionAsync.maybeWhen(
      data: (info) => info,
      orElse: () => CaptainSubscriptionInfo.none(),
    );
    final warnSubscription = subscriptionInfo.hasActiveSubscription;

    return AccountPageLayout(
      pageTitle: l10n.accountTitle,
      fullName: user?.fullName ?? '',
      phoneDisplay: phoneDisplay,
      logoutLabel: l10n.signOut,
      onLogout: () => _signOut(ref, context),
      sections: [
        AccountScreenSections.captainSubscription(
          l10n: l10n,
          body: CaptainSubscriptionAccordionBody(info: subscriptionInfo),
        ),
        AccountScreenSections.settings(
          l10n: l10n,
          rows: [
            const AccountThemeSettingRow(),
            AccountSettingsRow(
              label: l10n.accountNotifications,
              onTap: () => context.push('/notifications'),
              showDivider: false,
            ),
          ],
        ),
        AccountScreenSections.privacySecurity(
          l10n: l10n,
          context: context,
          onDeleteAccount: () => _onDeleteAccount(
            context,
            ref,
            warnActiveSubscription: warnSubscription,
          ),
        ),
        AccountScreenSections.appInfo(l10n: l10n, context: context),
        AccountScreenSections.technicalSupport(l10n: l10n, context: context),
      ],
    );
  }
}
