import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/legal/domain/entities/legal_document.dart';
import 'package:hather_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({
    required this.documentType,
    required this.fallbackTitle,
    super.key,
  });

  final LegalDocumentType documentType;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncDoc = ref.watch(legalDocumentProvider(documentType));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          asyncDoc.asData?.value.title ?? fallbackTitle,
          style: AppTextStyles.sectionTitle,
        ),
      ),
      body: asyncDoc.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LegalLoadError(
          message: l10n.legalContentLoadFailed,
          retryLabel: l10n.retryAction,
          onRetry: () => ref.invalidate(legalDocumentProvider(documentType)),
        ),
        data: (doc) => Markdown(
          data: doc.content,
          selectable: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          styleSheet: MarkdownStyleSheet.fromTheme(
            Theme.of(context),
          ).copyWith(
            p: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.65,
            ),
            h1: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.textPrimary,
              fontSize: 22,
              height: 1.4,
            ),
            h2: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
              height: 1.4,
            ),
            h3: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
              height: 1.4,
            ),
            listBullet: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.65,
            ),
            strong: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLoadError extends StatelessWidget {
  const _LegalLoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
