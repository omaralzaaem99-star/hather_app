import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';
import 'package:hather_app/l10n/app_localizations.dart';

enum CaptainRejectionSyncOutcome { success, profileRefreshFailed }

class CaptainRejectionSyncResult {
  const CaptainRejectionSyncResult({
    required this.outcome,
    this.route,
    this.user,
  });

  final CaptainRejectionSyncOutcome outcome;
  final String? route;
  final AuthUser? user;

  bool get isSuccess => outcome == CaptainRejectionSyncOutcome.success;
}

/// Syncs local auth state after admin rejects a captain conversion request.
abstract final class CaptainRejectionSync {
  static void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('CAPTAIN REJECTED: $message');
  }

  static Future<CaptainRejectionSyncResult> syncAfterRejection(
    WidgetRef ref,
  ) async {
    _log('notification received');

    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      _log('skipped — no session');
      return const CaptainRejectionSyncResult(
        outcome: CaptainRejectionSyncOutcome.profileRefreshFailed,
      );
    }

    _log('refreshing profile');
    final refreshed =
        await ref.read(authControllerProvider.notifier).refreshProfile();
    if (!refreshed) {
      _log('profile refresh failed');
      _log('keeping existing session');
      return const CaptainRejectionSyncResult(
        outcome: CaptainRejectionSyncOutcome.profileRefreshFailed,
      );
    }

    final user = ref.read(authControllerProvider).user;
    final route = AuthenticatedRoutes.homeFor(user);
    _log('profile refresh success');
    if (user != null) {
      _log(
        'new type=${user.accountType.name} status=${user.accountStatus.name}',
      );
    }
    _log('routing to $route');

    return CaptainRejectionSyncResult(
      outcome: CaptainRejectionSyncOutcome.success,
      route: route,
      user: user,
    );
  }

  static void applySyncResult({
    required WidgetRef ref,
    required CaptainRejectionSyncResult result,
    BuildContext? context,
    GoRouter? router,
    GlobalKey<NavigatorState>? navigatorKey,
    UserNotification? notification,
    String? fallbackBody,
  }) {
    if (!result.isSuccess || result.route == null) {
      showRefreshFailedFeedback(
        ref: ref,
        context: context,
        navigatorKey: navigatorKey,
      );
      return;
    }

    if (router != null) {
      router.go(result.route!);
    } else if (context != null && context.mounted) {
      context.go(result.route!);
    }

    showRejectedFeedback(
      context: context,
      navigatorKey: navigatorKey,
      notification: notification,
      fallbackBody: fallbackBody,
    );
  }

  static void showRejectedFeedback({
    BuildContext? context,
    GlobalKey<NavigatorState>? navigatorKey,
    UserNotification? notification,
    String? fallbackBody,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final snackContext = _snackContext(context, navigatorKey);
      if (snackContext == null || !snackContext.mounted) return;

      final l10n = AppLocalizations.of(snackContext);
      final body = notification?.body.trim() ?? fallbackBody?.trim();
      final message = (body != null && body.isNotEmpty)
          ? body
          : l10n.captainRejectionMessage;

      ScaffoldMessenger.of(snackContext).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  static void showRefreshFailedFeedback({
    required WidgetRef ref,
    BuildContext? context,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final snackContext = _snackContext(context, navigatorKey);
      if (snackContext == null || !snackContext.mounted) return;

      final l10n = AppLocalizations.of(snackContext);
      ScaffoldMessenger.of(snackContext).showSnackBar(
        SnackBar(
          content: Text(l10n.captainRejectionRefreshFailed),
          action: SnackBarAction(
            label: l10n.retryAction,
            onPressed: () {
              unawaited(
                syncAfterRejection(ref).then(
                  (retry) => applySyncResult(
                    ref: ref,
                    result: retry,
                    context: snackContext,
                    navigatorKey: navigatorKey,
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  static BuildContext? _snackContext(
    BuildContext? context,
    GlobalKey<NavigatorState>? navigatorKey,
  ) {
    if (context != null && context.mounted) return context;
    final navContext = navigatorKey?.currentContext;
    if (navContext != null && navContext.mounted) return navContext;
    return null;
  }
}
