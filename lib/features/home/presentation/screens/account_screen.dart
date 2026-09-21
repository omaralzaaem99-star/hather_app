import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/account/presentation/widgets/account_page_layout.dart';
import 'package:hather_app/features/account/presentation/widgets/account_screen_sections.dart';
import 'package:hather_app/features/account/presentation/widgets/account_theme_setting_row.dart';
import 'package:hather_app/features/account/presentation/widgets/account_widgets.dart';
import 'package:hather_app/features/account/presentation/widgets/delete_account_flow.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _converting = false;

  String get _phoneDisplay {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return '—';
    return PhoneNumberFormatter.toLocalDisplay(user.phone) ?? user.phone;
  }

  Future<void> _convertToCaptain() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          l10n.convertToCaptainTitle,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          l10n.convertToCaptainConfirm,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _converting = true);
    final ok =
        await ref.read(authControllerProvider.notifier).convertToCaptain();
    if (!mounted) return;
    setState(() => _converting = false);

    if (ok) {
      context.go(AuthenticatedRoutes.captainPending);
      return;
    }

    final failure = ref.read(authControllerProvider).failure;
    final message = failure == null
        ? l10n.errorUnknown
        : mapFailureToMessage(context, failure);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onDeleteAccount() async {
    await showDeleteAccountFlow(context, ref: ref);
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).user;
    final isUser = user?.accountType == AccountType.user;

    return AccountPageLayout(
      pageTitle: l10n.accountTitle,
      fullName: user?.fullName ?? '',
      phoneDisplay: _phoneDisplay,
      logoutLabel: l10n.signOut,
      onLogout: _signOut,
      sections: [
        AccountScreenSections.settings(
          l10n: l10n,
          initiallyExpanded: true,
          rows: [
            const AccountThemeSettingRow(),
            AccountSettingsRow(
              label: l10n.accountNotifications,
              onTap: () => context.push('/notifications'),
              showDivider: isUser,
            ),
            if (isUser)
              AccountSettingsRow(
                label: _converting
                    ? '${l10n.convertToCaptainAction}…'
                    : l10n.convertToCaptainAction,
                onTap: _converting ? null : _convertToCaptain,
                showDivider: false,
              ),
          ],
        ),
        AccountScreenSections.privacySecurity(
          l10n: l10n,
          context: context,
          onDeleteAccount: _onDeleteAccount,
        ),
        AccountScreenSections.appInfo(l10n: l10n, context: context),
        AccountScreenSections.technicalSupport(l10n: l10n, context: context),
      ],
    );
  }
}
