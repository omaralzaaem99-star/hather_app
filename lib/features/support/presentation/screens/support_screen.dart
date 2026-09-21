import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/support/core/support_launcher.dart';
import 'package:hather_app/features/support/domain/entities/support_faq.dart';
import 'package:hather_app/features/support/domain/entities/support_form.dart';
import 'package:hather_app/features/support/domain/entities/support_request.dart';
import 'package:hather_app/features/support/domain/entities/support_settings.dart';
import 'package:hather_app/features/support/presentation/providers/support_providers.dart';
import 'package:hather_app/features/support/presentation/widgets/support_widgets.dart';
import 'package:hather_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(supportSettingsProvider);
      ref.invalidate(supportFaqsProvider);
      ref.invalidate(supportFormsProvider);
      ref.invalidate(mySupportRequestsProvider);
    });
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  Future<void> _launchFirstAvailable(
    Iterable<Uri> uris, {
    required VoidCallback onFailure,
  }) async {
    for (final uri in uris) {
      if (await _tryLaunch(uri)) return;
    }
    onFailure();
  }

  void _showLaunchFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).supportLaunchFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(supportSettingsProvider);
    final faqsAsync = ref.watch(supportFaqsProvider);
    final formsAsync = ref.watch(supportFormsProvider);
    final requestsAsync = ref.watch(mySupportRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(l10n.supportScreenTitle, style: AppTextStyles.sectionTitle),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _SupportHubBody(
          l10n: l10n,
          settings: SupportSettings.empty(),
          faqs: faqsAsync.value ?? const [],
          forms: formsAsync.value ?? const [],
          requests: requestsAsync.value ?? const [],
          onOpenWhatsApp: (n) => _launchFirstAvailable(
            SupportLauncher.whatsAppLaunchUris(n),
            onFailure: _showLaunchFailed,
          ),
          onOpenPhone: (n) async {
            if (!await _tryLaunch(SupportLauncher.telUri(n))) _showLaunchFailed();
          },
          onOpenEmail: (e) async {
            if (!await _tryLaunch(SupportLauncher.mailtoUri(e))) {
              _showLaunchFailed();
            }
          },
          onOpenForm: (id) => context.push(AuthenticatedRoutes.supportFormPath(id)),
          onOpenRequest: (id) =>
              context.push(AuthenticatedRoutes.supportRequestPath(id)),
        ),
        data: (settings) => _SupportHubBody(
          l10n: l10n,
          settings: settings,
          faqs: faqsAsync.value ?? const [],
          forms: formsAsync.value ?? const [],
          requests: requestsAsync.value ?? const [],
          onOpenWhatsApp: (n) => _launchFirstAvailable(
            SupportLauncher.whatsAppLaunchUris(n),
            onFailure: _showLaunchFailed,
          ),
          onOpenPhone: (n) async {
            if (!await _tryLaunch(SupportLauncher.telUri(n))) _showLaunchFailed();
          },
          onOpenEmail: (e) async {
            if (!await _tryLaunch(SupportLauncher.mailtoUri(e))) {
              _showLaunchFailed();
            }
          },
          onOpenForm: (id) => context.push(AuthenticatedRoutes.supportFormPath(id)),
          onOpenRequest: (id) =>
              context.push(AuthenticatedRoutes.supportRequestPath(id)),
        ),
      ),
    );
  }
}

class _SupportHubBody extends StatelessWidget {
  const _SupportHubBody({
    required this.l10n,
    required this.settings,
    required this.faqs,
    required this.forms,
    required this.requests,
    required this.onOpenWhatsApp,
    required this.onOpenPhone,
    required this.onOpenEmail,
    required this.onOpenForm,
    required this.onOpenRequest,
  });

  final AppLocalizations l10n;
  final SupportSettings settings;
  final List<SupportFaq> faqs;
  final List<SupportFormSummary> forms;
  final List<SupportRequestSummary> requests;
  final Future<void> Function(String) onOpenWhatsApp;
  final Future<void> Function(String) onOpenPhone;
  final Future<void> Function(String) onOpenEmail;
  final ValueChanged<String> onOpenForm;
  final ValueChanged<String> onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final message = settings.supportMessage?.trim().isNotEmpty == true
        ? settings.supportMessage!.trim()
        : l10n.supportDefaultMessage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          message,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            height: 1.65,
          ),
        ),
        const SupportDivider(),
        SupportSectionHeader(title: '📞 ${l10n.supportContactUs}'),
        if (!settings.hasAnyChannel)
          SupportEmptyCard(message: l10n.supportNoChannels)
        else ...[
          if (settings.hasWhatsappChannel)
            _ContactCard(
              icon: '🟢',
              title: l10n.supportChannelWhatsapp,
              subtitle: PhoneNumberFormatter.toLocalDisplay(
                    settings.whatsappNumber!,
                  ) ??
                  settings.whatsappNumber!,
              onTap: () => onOpenWhatsApp(settings.whatsappNumber!),
            ),
          if (settings.hasPhoneChannel)
            _ContactCard(
              icon: '📞',
              title: l10n.supportChannelPhone,
              subtitle: PhoneNumberFormatter.toLocalDisplay(
                    settings.phoneNumber!,
                  ) ??
                  settings.phoneNumber!,
              onTap: () => onOpenPhone(settings.phoneNumber!),
            ),
          if (settings.hasEmailChannel)
            _ContactCard(
              icon: '✉️',
              title: l10n.supportChannelEmail,
              subtitle: settings.emailAddress!,
              onTap: () => onOpenEmail(settings.emailAddress!),
            ),
        ],
        const SupportDivider(),
        SupportSectionHeader(title: l10n.supportFaqsTitle),
        if (faqs.isEmpty)
          SupportEmptyCard(message: l10n.supportNoFaqs)
        else
          ...faqs.map((faq) => _FaqTile(faq: faq)),
        const SupportDivider(),
        SupportSectionHeader(title: l10n.supportFormsTitle),
        if (forms.isEmpty)
          SupportEmptyCard(message: l10n.supportNoForms)
        else
          ...forms.map(
            (form) => SupportLinkCard(
              icon: '📝',
              title: form.title,
              subtitle: form.description,
              onTap: () => onOpenForm(form.id),
            ),
          ),
        const SupportDivider(),
        SupportSectionHeader(title: l10n.supportMyRequestsTitle),
        if (requests.isEmpty)
          SupportEmptyCard(message: l10n.supportNoRequests)
        else
          ...requests.map(
            (req) => _RequestTile(
              request: req,
              l10n: l10n,
              onTap: () => onOpenRequest(req.id),
            ),
          ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.borderSubtle.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor:
                              AppColors.textSecondary.withValues(alpha: 0.45),
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final SupportFaq faq;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: AppColors.icon,
            collapsedIconColor: AppColors.textMuted,
            title: Text(
              faq.question,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  faq.answer,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.l10n,
    required this.onTap,
  });

  final SupportRequestSummary request;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  String _statusLabel() {
    return switch (request.status) {
      SupportRequestStatus.newRequest => l10n.supportStatusNew,
      SupportRequestStatus.inProgress => l10n.supportStatusInProgress,
      SupportRequestStatus.resolved => l10n.supportStatusResolved,
      SupportRequestStatus.closed => l10n.supportStatusClosed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = request.createdAt != null
        ? AppDateTimeFormat.dateTime(request.createdAt!)
        : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(request.formTitle, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  '#${request.requestNumber}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.end,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusChip(label: _statusLabel()),
                    const Spacer(),
                    Text(
                      date,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
