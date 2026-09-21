import 'package:flutter/material.dart';
import 'package:hather_app/core/constants/app_info.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/delivery/presentation/utils/order_contact_launcher.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Developer contact footer on the About screen — phone tap opens WhatsApp/call sheet.
class AboutDeveloperSection extends StatelessWidget {
  const AboutDeveloperSection({super.key});

  Future<void> _call(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = OrderContactLauncher.telUri(AppInfo.developerPhoneE164);
    if (uri == null) {
      _showLaunchFailed(context, l10n.captainCallLaunchFailed);
      return;
    }
    final ok = await OrderContactLauncher.tryLaunch(uri);
    if (!context.mounted) return;
    if (!ok) _showLaunchFailed(context, l10n.captainCallLaunchFailed);
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uris =
        OrderContactLauncher.whatsAppLaunchUris(AppInfo.developerPhoneE164);
    if (uris.isEmpty) {
      _showLaunchFailed(context, l10n.captainWhatsAppLaunchFailed);
      return;
    }
    final ok = await OrderContactLauncher.launchFirst(uris);
    if (!context.mounted) return;
    if (!ok) _showLaunchFailed(context, l10n.captainWhatsAppLaunchFailed);
  }

  void _showLaunchFailed(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showContactSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                AppInfo.developerPhoneLocal,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.chat, color: AppColors.whatsApp),
                title: Text(l10n.captainWhatsAppAction),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openWhatsApp(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.phone, color: AppColors.icon),
                title: Text(l10n.captainCallAction),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _call(context);
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancelAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: AppColors.divider.withValues(alpha: 0.5)),
        const SizedBox(height: 24),
        Text(
          AppInfo.developerCreditLabel,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          AppInfo.developerName,
          style: AppTextStyles.bodyStrong,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showContactSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: AppColors.icon,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppInfo.developerPhoneLocal,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.icon,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
