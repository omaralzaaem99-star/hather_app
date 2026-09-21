import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/app/app_router.dart';
import 'package:hather_app/core/notifications/fcm_notification_service.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Binds FCM navigation + app resume sync without coupling to feature UI.
class FcmBootstrap extends ConsumerStatefulWidget {
  const FcmBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FcmBootstrap> createState() => _FcmBootstrapState();
}

class _FcmBootstrapState extends ConsumerState<FcmBootstrap>
    with WidgetsBindingObserver {
  bool _permissionFeedbackScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FcmNotificationService.instance.syncCurrentDevice();
      ref.read(authControllerProvider.notifier).onAppResumed();
    }
  }

  void _schedulePendingNavigationFlush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FcmNotificationService.instance.flushPendingNavigation();
    });
  }

  void _schedulePermissionDeniedFeedbackOnce() {
    if (_permissionFeedbackScheduled) return;
    _permissionFeedbackScheduled = true;
    _attemptPermissionDeniedFeedback();
  }

  void _attemptPermissionDeniedFeedback({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FcmNotificationService.instance.pendingPermissionDeniedFeedback ==
          null) {
        return;
      }

      // FcmBootstrap wraps MaterialApp — use the router navigator context.
      final navContext =
          ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;
      final messenger =
          navContext != null && navContext.mounted
              ? ScaffoldMessenger.maybeOf(navContext)
              : null;
      if (navContext == null || !navContext.mounted || messenger == null) {
        if (attempt < 40) {
          _attemptPermissionDeniedFeedback(attempt: attempt + 1);
        }
        return;
      }

      final feedback = FcmNotificationService.instance
          .takePendingPermissionDeniedFeedback();
      if (feedback == null) return;

      final l10n = AppLocalizations.of(navContext);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.notificationPermissionDenied),
          duration: const Duration(seconds: 6),
          action: feedback.offerOpenSettings
              ? SnackBarAction(
                  label: l10n.openAppSettingsAction,
                  onPressed: () {
                    // Soft recovery only — never re-prompt the system dialog.
                    launchUrl(
                      Uri.parse('app-settings:'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                )
              : null,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    FcmNotificationService.instance.bindWidgetRef(ref);
    FcmNotificationService.instance.bindRouter(ref.read(goRouterProvider));

    ref.listen(authControllerProvider, (previous, next) {
      if (next.isAuthenticated &&
          FcmNotificationService.instance.hasPendingNavigation) {
        _schedulePendingNavigationFlush();
      }
    });

    _schedulePendingNavigationFlush();
    _schedulePermissionDeniedFeedbackOnce();
    return widget.child;
  }
}
