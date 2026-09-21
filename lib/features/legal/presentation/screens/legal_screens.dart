import 'package:flutter/material.dart';
import 'package:hather_app/core/constants/app_info.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/legal/domain/entities/legal_document.dart';
import 'package:hather_app/features/legal/presentation/screens/legal_document_screen.dart';
import 'package:hather_app/features/legal/presentation/widgets/about_developer_section.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LegalDocumentScreen(
      documentType: LegalDocumentType.privacyPolicy,
      fallbackTitle: l10n.accountPrivacyPolicy,
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LegalDocumentScreen(
      documentType: LegalDocumentType.termsOfUse,
      fallbackTitle: l10n.accountTerms,
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(l10n.accountAbout, style: AppTextStyles.sectionTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppInfo.appName,
              style: AppTextStyles.brandTitle.copyWith(fontSize: 32),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppInfo.aboutDescription,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.65,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Text(
              l10n.aboutVersionLabel,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${AppInfo.version} (${AppInfo.buildNumber})',
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            ),
            const Spacer(),
            const AboutDeveloperSection(),
          ],
        ),
      ),
    );
  }
}
