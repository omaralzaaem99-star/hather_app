import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/features/support/domain/entities/support_request.dart';
import 'package:hather_app/features/support/presentation/providers/support_providers.dart';
import 'package:hather_app/features/support/presentation/widgets/support_widgets.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class SupportRequestDetailScreen extends ConsumerWidget {
  const SupportRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  String _statusLabel(AppLocalizations l10n, SupportRequestStatus status) {
    return switch (status) {
      SupportRequestStatus.newRequest => l10n.supportStatusNew,
      SupportRequestStatus.inProgress => l10n.supportStatusInProgress,
      SupportRequestStatus.resolved => l10n.supportStatusResolved,
      SupportRequestStatus.closed => l10n.supportStatusClosed,
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return AppDateTimeFormat.dateTime(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(mySupportRequestDetailProvider(requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          l10n.supportRequestDetailTitle,
          style: AppTextStyles.sectionTitle,
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.supportSubmitFailed,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (detail) => ListView(
          padding: AppDimensions.scrollPadding(context, top: 12, bottom: 32),
          children: [
            Text(
              detail.formTitle,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: l10n.supportRequestNumberLabel,
              value: '#${detail.requestNumber}',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  l10n.supportRequestTypeLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                _StatusChip(label: _statusLabel(l10n, detail.status)),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: l10n.supportRequestSubmittedAtLabel,
              value: _formatDate(detail.createdAt),
            ),
            const SupportDivider(),
            SupportSectionHeader(title: l10n.supportYourAnswersTitle),
            if (detail.answers.isEmpty)
              SupportEmptyCard(message: l10n.supportNoRequests)
            else
              ...detail.answers.map(
                (answer) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.borderSubtle.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          answer.label,
                          style: AppTextStyles.bodyStrong,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          answer.value,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SupportDivider(),
            SupportSectionHeader(title: l10n.supportAdminReplyTitle),
            if (!detail.hasAdminReply)
              SupportEmptyCard(message: l10n.supportNoAdminReplyYet)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.icon.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      detail.adminReply!.trim(),
                      style: AppTextStyles.body.copyWith(height: 1.65),
                    ),
                    if (detail.repliedAt != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _formatDate(detail.repliedAt),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyStrong,
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.icon.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.icon,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
