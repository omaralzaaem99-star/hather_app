import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/features/account/presentation/widgets/account_widgets.dart';

/// Shared account page — fixed profile banner + separate section cards.
class AccountPageLayout extends StatelessWidget {
  const AccountPageLayout({
    required this.pageTitle,
    required this.fullName,
    required this.phoneDisplay,
    required this.sections,
    required this.logoutLabel,
    required this.onLogout,
    super.key,
  });

  final String pageTitle;
  final String fullName;
  final String phoneDisplay;
  final List<Widget> sections;
  final String logoutLabel;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountProfileHeader(
              pageTitle: pageTitle,
              fullName: fullName,
              phoneDisplay: phoneDisplay,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 110),
                child: AccountSectionCardsList(
                  sections: sections,
                  logoutLabel: logoutLabel,
                  onLogout: onLogout,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
