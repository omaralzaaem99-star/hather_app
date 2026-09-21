import 'package:flutter/material.dart';
import 'package:hather_app/core/routing/safe_navigation.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Full content for general / non-routable notifications.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final UserNotification notification;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.textPrimary,
          onPressed: () => safeBack(context, fallbackLocation: '/notifications'),
        ),
        title: Text(l10n.notificationsTitle, style: AppTextStyles.screenTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.title, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 10),
              Text(notification.body, style: AppTextStyles.body),
              const SizedBox(height: 14),
              Text(
                AppDateTimeFormat.dateTime(notification.createdAt),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
