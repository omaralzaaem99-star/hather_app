import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hather_app/core/notifications/fcm_payload_contract.dart';

typedef LocalNotificationTapHandler = void Function(FcmPushPayload payload);

/// Foreground-only visible notifications (background uses FCM system tray).
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const channelId = 'hather_default';
  static const channelName = 'إشعارات حاضر';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  LocalNotificationTapHandler? _onTap;
  bool _initialized = false;

  Future<void> initialize({required LocalNotificationTapHandler onTap}) async {
    if (_initialized) return;
    _onTap = onTap;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        final payload = decodePayload(details.payload);
        if (payload != null) {
          _onTap?.call(payload);
        }
      },
    );

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      importance: Importance.high,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showForegroundNotification({
    required String title,
    required String body,
    required FcmPushPayload payload,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    await _plugin.show(
      _notificationIdFor(payload),
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: encodePayload(payload),
    );
  }

  static int _notificationIdFor(FcmPushPayload payload) {
    final id = payload.notificationId;
    if (id != null && id.isNotEmpty) return id.hashCode;
    return DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  }

  static String encodePayload(FcmPushPayload payload) {
    return jsonEncode({
      if (payload.type != null) FcmPayloadContract.type: payload.type,
      if (payload.notificationId != null)
        FcmPayloadContract.notificationId: payload.notificationId,
      if (payload.orderId != null) FcmPayloadContract.orderId: payload.orderId,
      if (payload.supportRequestId != null)
        FcmPayloadContract.supportRequestId: payload.supportRequestId,
      if (payload.tapDestination != null)
        FcmPayloadContract.tapDestination: payload.tapDestination,
    });
  }

  static FcmPushPayload? decodePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FcmPushPayload(
        type: map[FcmPayloadContract.type]?.toString(),
        notificationId: map[FcmPayloadContract.notificationId]?.toString(),
        orderId: map[FcmPayloadContract.orderId]?.toString(),
        supportRequestId: map[FcmPayloadContract.supportRequestId]?.toString(),
        tapDestination: map[FcmPayloadContract.tapDestination]?.toString(),
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Local notification payload decode failed: $error');
      }
      return null;
    }
  }
}
