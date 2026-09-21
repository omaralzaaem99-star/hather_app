import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/app/app_router.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/notifications/account_reactivated_sync.dart';
import 'package:hather_app/core/notifications/captain_rejection_sync.dart';
import 'package:hather_app/core/notifications/expired_order_dialog.dart';
import 'package:hather_app/core/notifications/fcm_payload_contract.dart';
import 'package:hather_app/core/notifications/local_notification_service.dart';
import 'package:hather_app/core/notifications/notification_navigation.dart';
import 'package:hather_app/core/notifications/push_device_repository.dart';
import 'package:hather_app/core/notifications/push_installation_storage.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/captain/presentation/providers/captain_available_orders_push_refresh.dart';
import 'package:hather_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// One-shot UX after the user denies notification permission (no nag loop).
class NotificationPermissionDeniedFeedback {
  const NotificationPermissionDeniedFeedback({
    required this.offerOpenSettings,
  });

  /// When true, UI may offer a soft "open app settings" action.
  final bool offerOpenSettings;
}

/// Client-side Firebase Cloud Messaging setup and device token sync.
class FcmNotificationService {
  FcmNotificationService._();

  static final FcmNotificationService instance = FcmNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final PushInstallationStorage _installationStorage = PushInstallationStorage();
  final PushDeviceRepository _pushDevices = PushDeviceRepository();

  static const _permissionDeniedFeedbackKey =
      'fcm_notif_permission_denied_feedback_v1';

  ProviderContainer? _container;
  WidgetRef? _widgetRef;
  GoRouter? _router;
  bool _initialized = false;
  bool _syncInFlight = false;
  FcmPushPayload? _pendingNavigation;
  NotificationPermissionDeniedFeedback? _pendingPermissionDeniedFeedback;

  Future<void> initialize({required ProviderContainer container}) async {
    if (_initialized) return;
    _container = container;
    _initialized = true;

    await LocalNotificationService.instance.initialize(
      onTap: _onLocalNotificationTap,
    );

    await _requestPermissions();
    await _configureForegroundPresentation();
    _registerListeners();
    await _logInitialToken();
    await syncCurrentDevice();
    await _handleInitialMessage();
  }

  void bindWidgetRef(WidgetRef ref) {
    _widgetRef = ref;
    flushPendingNavigation();
  }

  void bindRouter(GoRouter router) {
    _router = router;
    flushPendingNavigation();
  }

  Future<void> deactivateCurrentInstallation() async {
    if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) return;
    try {
      final installationId = await _installationStorage.getOrCreate();
      await _pushDevices.deactivateMyDevice(installationId);
      if (kDebugMode) {
        debugPrint('FCM device deactivated on logout');
      }
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('FCM device deactivate failed: $error');
      }
    }
  }

  Future<void> syncCurrentDevice() async {
    if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) return;
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final token = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint(
          'FCM token available: ${token != null && token.trim().isNotEmpty ? 'yes' : 'no'}',
        );
      }
      if (token == null || token.trim().isEmpty) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (kDebugMode) {
        debugPrint('FCM sync auth user: ${user != null ? 'yes' : 'no'}');
      }
      if (user == null) return;

      final installationId = await _installationStorage.getOrCreate();
      final installationOk =
          installationId.trim().isNotEmpty &&
          Uuid.isValidUUID(fromString: installationId.trim());
      if (kDebugMode) {
        debugPrint(
          'FCM installation id available: ${installationOk ? 'yes' : 'no'}',
        );
      }
      if (!installationOk) {
        if (kDebugMode) {
          debugPrint('FCM device sync failed: invalid installation id');
        }
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';

      if (kDebugMode) {
        debugPrint('FCM device RPC start');
      }

      await _pushDevices.upsertMyDevice(
        installationId: installationId.trim(),
        fcmToken: token.trim(),
        platform: platform,
      );

      if (kDebugMode) {
        debugPrint('FCM device RPC success');
      }
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('FCM device sync failed: ${sanitizePushSyncError(error)}');
      }
    } finally {
      _syncInFlight = false;
    }
  }

  bool get hasPendingNavigation => _pendingNavigation != null;

  void flushPendingNavigation() {
    final payload = _pendingNavigation;
    if (payload == null) return;

    final ref = _widgetRef;
    final router = _router ?? _container?.read(goRouterProvider);
    if (ref == null || router == null || !_isNavigationReady(ref)) return;

    _pendingNavigation = null;
    unawaited(
      NotificationNavigation.handlePayloadWithRouter(
        router: router,
        ref: ref,
        payload: payload,
        navigatorKey: router.routerDelegate.navigatorKey,
      ),
    );
  }

  bool _isNavigationReady(WidgetRef ref) {
    return ref.read(authControllerProvider).isAuthenticated;
  }

  /// Peek without consuming (UI waits for ScaffoldMessenger readiness).
  NotificationPermissionDeniedFeedback? get pendingPermissionDeniedFeedback =>
      _pendingPermissionDeniedFeedback;

  /// Consumes one-shot denied-permission feedback for UI (SnackBar). Never loops.
  NotificationPermissionDeniedFeedback? takePendingPermissionDeniedFeedback() {
    final pending = _pendingPermissionDeniedFeedback;
    _pendingPermissionDeniedFeedback = null;
    return pending;
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('FCM permission status: ${settings.authorizationStatus.name}');
      if (Platform.isAndroid) {
        debugPrint('FCM Android 13+ notification permission requested');
      }
    }

    await _maybeQueuePermissionDeniedFeedback(settings.authorizationStatus);
  }

  Future<void> _maybeQueuePermissionDeniedFeedback(
    AuthorizationStatus status,
  ) async {
    final denied = status == AuthorizationStatus.denied;
    if (!denied) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_permissionDeniedFeedbackKey) == true) {
        return;
      }
      await prefs.setBool(_permissionDeniedFeedbackKey, true);
      // Denied is the recovery case: soft settings CTA once (no dialog loop).
      _pendingPermissionDeniedFeedback =
          const NotificationPermissionDeniedFeedback(offerOpenSettings: true);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('FCM permission feedback prefs failed: $error');
      }
    }
  }

  Future<void> _configureForegroundPresentation() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  void _registerListeners() {
    _messaging.onTokenRefresh.listen((token) {
      if (kDebugMode) {
        debugPrint('FCM token refreshed (${_tokenLogLabel(token)})');
      }
      unawaited(syncCurrentDevice());
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  Future<void> _logInitialToken() async {
    try {
      final token = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM token obtained: ${_tokenLogLabel(token)}');
      }
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('FCM token obtained: no ($error)');
      }
    }
  }

  Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _onTerminatedTap(message);
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final payload = FcmPushPayload.fromRemoteMessage(message);
    if (kDebugMode) {
      debugPrint('FCM foreground message: $payload');
    }

    refreshNotificationsFromPush();
    _maybeRefreshCaptainAvailableOrdersFromPush(payload);

    if (payload.type == 'captain_rejected') {
      _handleCaptainRejectedForeground(message, payload);
    }

    if (payload.type == 'account_reactivated') {
      _handleAccountReactivatedForeground();
    }

    if (payload.type == 'delivery_order_expired') {
      _handleExpiredOrderForeground(payload);
    }

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    unawaited(
      LocalNotificationService.instance.showForegroundNotification(
        title: title,
        body: body,
        payload: payload,
      ),
    );
  }

  void _handleExpiredOrderForeground(FcmPushPayload payload) {
    final ref = _widgetRef;
    final router = _router ?? _container?.read(goRouterProvider);
    if (ref == null || router == null || !_isNavigationReady(ref)) {
      return;
    }

    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    unawaited(
      ExpiredOrderDialog.showIfNeeded(
        context: context,
        orderId: payload.orderId,
        router: router,
        ref: ref,
      ),
    );
  }

  void _handleAccountReactivatedForeground() {
    final ref = _widgetRef;
    final router = _router ?? _container?.read(goRouterProvider);
    if (ref == null || router == null || !_isNavigationReady(ref)) {
      return;
    }

    final location = router.state.uri.path;
    if (!AccountReactivatedSync.isRestrictedRoute(location)) {
      return;
    }

    unawaited(
      AccountReactivatedSync.syncAfterReactivation(ref).then((result) {
        if (!result.isSuccess || result.route == null) return;
        router.go(result.route!);
      }),
    );
  }

  void _handleCaptainRejectedForeground(
    RemoteMessage message,
    FcmPushPayload payload,
  ) {
    final ref = _widgetRef;
    final router = _router ?? _container?.read(goRouterProvider);
    if (ref == null || router == null || !_isNavigationReady(ref)) {
      return;
    }

    final fallbackBody = message.notification?.body;
    unawaited(
      CaptainRejectionSync.syncAfterRejection(ref).then((result) {
        CaptainRejectionSync.applySyncResult(
          ref: ref,
          result: result,
          router: router,
          navigatorKey: router.routerDelegate.navigatorKey,
          fallbackBody: fallbackBody,
        );
      }),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final payload = FcmPushPayload.fromRemoteMessage(message);
    if (kDebugMode) {
      debugPrint('FCM notification tap (background): $payload');
    }
    _handleNotificationTap(payload);
  }

  void _onTerminatedTap(RemoteMessage message) {
    final payload = FcmPushPayload.fromRemoteMessage(message);
    if (kDebugMode) {
      debugPrint('FCM notification tap (terminated): $payload');
    }
    _handleNotificationTap(payload);
  }

  void _onLocalNotificationTap(FcmPushPayload payload) {
    if (kDebugMode) {
      debugPrint('FCM local notification tap: $payload');
    }
    _handleNotificationTap(payload);
  }

  void _handleNotificationTap(FcmPushPayload payload) {
    refreshNotificationsFromPush();
    _maybeRefreshCaptainAvailableOrdersFromPush(payload);

    final ref = _widgetRef;
    final router = _router ?? _container?.read(goRouterProvider);
    if (ref == null || router == null || !_isNavigationReady(ref)) {
      _pendingNavigation = payload;
      return;
    }

    unawaited(
      NotificationNavigation.handlePayloadWithRouter(
        router: router,
        ref: ref,
        payload: payload,
        navigatorKey: router.routerDelegate.navigatorKey,
      ),
    );
  }

  /// Refreshes unread count + list from Supabase — no local DB insert.
  void refreshNotificationsFromPush() {
    final container = _container;
    if (container == null) return;

    container.invalidate(unreadNotificationCountProvider);
    try {
      container.read(notificationsListControllerProvider.notifier).refresh();
    } on Object {
      // List controller may not be mounted yet on cold start.
    }
  }

  void _maybeRefreshCaptainAvailableOrdersFromPush(FcmPushPayload payload) {
    final container = _container;
    if (container == null) return;
    scheduleCaptainAvailableOrdersPushRefresh(
      container,
      notificationType: payload.type,
    );
  }

  static String _tokenLogLabel(String? token) {
    if (token == null || token.isEmpty) return 'no';
    if (kReleaseMode) return 'yes';
    return 'yes (${token.length} chars)';
  }
}
