import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/features/delivery/presentation/utils/order_contact_launcher.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class OrderCaptainContactSection extends StatelessWidget {
  const OrderCaptainContactSection({
    super.key,
    required this.captainName,
    required this.captainPhone,
  });

  final String? captainName;
  final String? captainPhone;

  bool get _hasPhone => OrderContactLauncher.hasCallablePhone(captainPhone);

  String? get _displayPhone => OrderContactLauncher.localDisplay(captainPhone);

  Future<void> _call(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = OrderContactLauncher.telUri(captainPhone);
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
    final uris = OrderContactLauncher.whatsAppLaunchUris(captainPhone);
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
    if (!_hasPhone) return;
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
                l10n.orderContactCaptainTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.phone, color: AppColors.icon),
                title: Text(l10n.captainCallAction),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _call(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: AppColors.whatsApp),
                title: Text(l10n.captainWhatsAppAction),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openWhatsApp(context);
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
    final l10n = AppLocalizations.of(context);
    final name = captainName?.trim();
    final phone = _displayPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (name != null && name.isNotEmpty) ...[
          Text(name, style: AppTextStyles.bodyStrong),
          const SizedBox(height: 8),
        ],
        if (phone != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showContactSheet(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            phone,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.captainCallAction,
                onPressed: () => _call(context),
                icon: const Icon(Icons.phone, size: 22),
                color: AppColors.icon,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: l10n.captainWhatsAppAction,
                onPressed: () => _openWhatsApp(context),
                icon: const Icon(Icons.chat, size: 22),
                color: AppColors.whatsApp,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 300;
              final callBtn = _ContactButton(
                label: l10n.captainCallAction,
                icon: Icons.phone,
                iconColor: AppColors.icon,
                onPressed: () => _call(context),
              );
              final waBtn = _ContactButton(
                label: l10n.captainWhatsAppAction,
                icon: Icons.chat,
                iconColor: AppColors.whatsApp,
                onPressed: () => _openWhatsApp(context),
              );
              if (stacked) {
                return Column(
                  children: [
                    callBtn,
                    const SizedBox(height: 10),
                    waBtn,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: callBtn),
                  const SizedBox(width: 10),
                  Expanded(child: waBtn),
                ],
              );
            },
          ),
        ] else ...[
          Text(
            l10n.orderCaptainPhoneUnavailable,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
