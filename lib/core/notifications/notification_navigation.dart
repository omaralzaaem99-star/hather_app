import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/notifications/account_reactivated_sync.dart';
import 'package:hather_app/core/notifications/captain_rejection_sync.dart';
import 'package:hather_app/core/notifications/expired_order_dialog.dart';
import 'package:hather_app/core/notifications/fcm_payload_contract.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';
import 'package:hather_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Shared navigation for in-app list taps, FCM taps, and local notifications.
class NotificationNavigation {
  const NotificationNavigation._();

  static const detailRoute = '/notifications/detail';

  static const Set<String> _orderLinkedTypes = {
    'delivery_order_available',
    'delivery_order_assigned',
    'delivery_order_released',
    'delivery_order_cancelled',
    'delivery_order_accepted',
    'delivery_order_completed',
    'delivery_order_searching_captain',
  };

  static Future<void> handleNotification({
    required BuildContext context,
    required WidgetRef ref,
    required UserNotification notification,
    bool markRead = true,
  }) async {
    await _markReadIfNeeded(
      ref: ref,
      notificationId: markRead && !notification.isRead ? notification.id : null,
    );

    if (!context.mounted) return;

    await navigateFromPayload(
      ref: ref,
      context: context,
      type: notification.type,
      orderId: notification.orderId,
      supportRequestId: notification.supportRequestId,
      tapDestination: notification.tapDestination,
      notification: notification,
    );
  }

  static Future<void> handlePayload({
    required BuildContext context,
    required WidgetRef ref,
    required FcmPushPayload payload,
    bool markRead = true,
  }) async {
    final notification = _notificationFromPayload(ref, payload);

    await _markReadIfNeeded(
      ref: ref,
      notificationId: markRead ? payload.notificationId : null,
    );

    if (!context.mounted) return;

    await navigateFromPayload(
      ref: ref,
      context: context,
      type: payload.type ?? notification?.type ?? '',
      orderId: payload.orderId ?? notification?.orderId,
      supportRequestId:
          payload.supportRequestId ?? notification?.supportRequestId,
      tapDestination: payload.tapDestination ?? notification?.tapDestination,
      notification: notification,
    );
  }

  static Future<void> handlePayloadWithRouter({
    required GoRouter router,
    required WidgetRef ref,
    required FcmPushPayload payload,
    required GlobalKey<NavigatorState> navigatorKey,
    bool markRead = true,
  }) async {
    final notification = _notificationFromPayload(ref, payload);

    await _markReadIfNeeded(
      ref: ref,
      notificationId: markRead ? payload.notificationId : null,
    );

    await navigateFromPayload(
      ref: ref,
      router: router,
      navigatorKey: navigatorKey,
      type: payload.type ?? notification?.type ?? '',
      orderId: payload.orderId ?? notification?.orderId,
      supportRequestId:
          payload.supportRequestId ?? notification?.supportRequestId,
      tapDestination: payload.tapDestination ?? notification?.tapDestination,
      notification: notification,
    );
  }

  static UserNotification? _notificationFromPayload(
    WidgetRef ref,
    FcmPushPayload payload,
  ) {
    final id = payload.notificationId;
    if (id == null || id.isEmpty) return null;
    for (final item in ref.read(notificationsListControllerProvider).items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static Future<void> navigateFromPayload({
    required WidgetRef ref,
    BuildContext? context,
    GoRouter? router,
    GlobalKey<NavigatorState>? navigatorKey,
    required String type,
    String? orderId,
    String? supportRequestId,
    String? tapDestination,
    UserNotification? notification,
  }) async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      if (kDebugMode) {
        debugPrint(
          'Notification navigation deferred: auth not ready (type=$type)',
        );
      }
      return;
    }

    if (type == 'captain_rejected') {
      final result = await CaptainRejectionSync.syncAfterRejection(ref);
      CaptainRejectionSync.applySyncResult(
        ref: ref,
        result: result,
        context: context,
        router: router,
        navigatorKey: navigatorKey,
        notification: notification,
      );
      return;
    }

    if (type == 'account_reactivated') {
      final result = await AccountReactivatedSync.syncAfterReactivation(ref);
      if (result.isSuccess && result.route != null) {
        if (router != null) {
          router.go(result.route!);
        } else if (context != null && context.mounted) {
          context.go(result.route!);
        }
      }
      return;
    }

    if (type == 'captain_approved') {
      await ref.read(authControllerProvider.notifier).refreshProfile();
    }

    if (context != null && !context.mounted) return;

    final user = ref.read(authControllerProvider).user;

    if (type == 'delivery_order_expired') {
      final dialogContext = _dialogContext(
        context: context,
        navigatorKey: navigatorKey,
      );
      if (dialogContext != null && dialogContext.mounted) {
        await ExpiredOrderDialog.showIfNeeded(
          context: dialogContext,
          orderId: orderId,
          router: router,
          ref: ref,
        );
      }
      return;
    }

    final location = resolveLocation(
      user: user,
      type: type,
      orderId: orderId,
      supportRequestId: supportRequestId,
      tapDestination: tapDestination,
      notification: notification,
    );

    if (location == null) {
      if (notification != null) {
        _openDetail(
          context: context,
          router: router,
          notification: notification,
        );
      }
      return;
    }

    if (location == detailRoute) {
      if (notification != null) {
        _openDetail(
          context: context,
          router: router,
          notification: notification,
        );
      }
      return;
    }

    if (router != null) {
      router.push(location);
      _showPostNavigationFeedback(
        type: type,
        context: context,
        navigatorKey: navigatorKey,
      );
      return;
    }

    if (context != null && context.mounted) {
      context.push(location);
      _showPostNavigationFeedback(
        type: type,
        context: context,
        navigatorKey: navigatorKey,
      );
    }
  }

  static void _openDetail({
    BuildContext? context,
    GoRouter? router,
    required UserNotification notification,
  }) {
    if (router != null) {
      router.push(detailRoute, extra: notification);
      return;
    }
    if (context != null && context.mounted) {
      context.push(detailRoute, extra: notification);
    }
  }

  static void _showPostNavigationFeedback({
    required String type,
    BuildContext? context,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    if (type != 'delivery_order_released') return;

    final snackContext = _dialogContext(
      context: context,
      navigatorKey: navigatorKey,
    );
    if (snackContext == null || !snackContext.mounted) return;

    final l10n = AppLocalizations.of(snackContext);
    ScaffoldMessenger.of(snackContext).showSnackBar(
      SnackBar(content: Text(l10n.notificationOrderReleased)),
    );
  }

  /// Role-aware route resolution — no arbitrary server routes.
  @visibleForTesting
  static String? resolveLocation({
    required AuthUser? user,
    required String type,
    String? orderId,
    String? supportRequestId,
    String? tapDestination,
    UserNotification? notification,
  }) {
    final zone = AuthenticatedRoutes.zoneFor(user);
    final hasOrderId = orderId != null && orderId.isNotEmpty;

    // Captain-only: handle before generic order-linked routing (ownership may be cleared).
    if (zone == AccountRouteZone.captainActive) {
      if (type == 'delivery_order_released') {
        return AuthenticatedRoutes.captainHome;
      }
      if (type == 'delivery_order_cancelled') {
        return _detailFallback(notification);
      }
    }

    if (_orderLinkedTypes.contains(type) && hasOrderId) {
      final orderRoute = _resolveOrderLocation(zone: zone, orderId: orderId);
      if (orderRoute != null) return orderRoute;
    }

    if (type == 'admin_broadcast') {
      return switch (tapDestination) {
        'home' => AuthenticatedRoutes.homeFor(user),
        'none' => notification != null ? detailRoute : null,
        _ => detailRoute,
      };
    }

    if (type == 'support_reply') {
      if (supportRequestId == null || supportRequestId.isEmpty) {
        return _detailFallback(notification);
      }
      return AuthenticatedRoutes.supportRequestPath(supportRequestId);
    }

    if (type == 'captain_approved') {
      if (zone == AccountRouteZone.captainPending ||
          zone == AccountRouteZone.captainActive) {
        return AuthenticatedRoutes.captainHome;
      }
      return _detailFallback(notification);
    }

    if (type == 'subscription_activated') {
      if (zone == AccountRouteZone.captainActive) {
        return AuthenticatedRoutes.captainAccount;
      }
      return _detailFallback(notification);
    }

    if (type == 'captain_rejected') {
      return AuthenticatedRoutes.homeFor(user);
    }

    if (type == 'captain_suspended') {
      return AuthenticatedRoutes.captainSuspended;
    }

    if (type == 'captain_disabled') {
      return AuthenticatedRoutes.captainDisabled;
    }

    if (type == 'account_reactivated') {
      return AuthenticatedRoutes.homeFor(user);
    }

    if (_orderLinkedTypes.contains(type) && !hasOrderId) {
      return _detailFallback(notification);
    }

    if (type.isEmpty) {
      return _detailFallback(notification);
    }

    return detailRoute;
  }

  static String? _resolveOrderLocation({
    required AccountRouteZone zone,
    required String orderId,
  }) {
    if (zone == AccountRouteZone.captainActive) {
      return AuthenticatedRoutes.captainAvailableOrderPath(orderId);
    }
    if (zone == AccountRouteZone.user) {
      return '/delivery/orders/$orderId';
    }
    return null;
  }

  static String? _detailFallback(UserNotification? notification) {
    if (kDebugMode && notification == null) {
      debugPrint('Notification navigation falling back to detail without item');
    }
    return detailRoute;
  }

  static Future<void> _markReadIfNeeded({
    required WidgetRef ref,
    String? notificationId,
  }) async {
    if (notificationId == null || notificationId.isEmpty) return;
    try {
      await ref
          .read(notificationsListControllerProvider.notifier)
          .markRead(notificationId);
    } on Object {
      // Navigation must not be blocked when mark-as-read fails.
    }
  }

  static BuildContext? _dialogContext({
    BuildContext? context,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    if (context != null && context.mounted) return context;
    final navContext = navigatorKey?.currentContext;
    if (navContext != null && navContext.mounted) return navContext;
    return null;
  }
}
